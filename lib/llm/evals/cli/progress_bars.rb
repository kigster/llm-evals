# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # dry-cli-ui's multi_progress, drawn differently:
      #
      # - a flat list, the jobs indented under the headline, with no tree;
      # - the headline's bar, which counts every case, in yellow;
      # - a finished job keeps its bar, full, with the time it took where the
      #   ETA was, instead of turning into a one-line summary;
      # - on a screen too short for every job, a finished row stays for
      #   {LINGER} seconds, since a short job would otherwise leave the screen
      #   before anyone saw it full: at two cases, its last frame is 50%;
      # - labels padded to at least {LABEL_WIDTH} columns, in the columns
      #   {.labels} lays out, each model in a bright color of its own for the
      #   whole run, chosen at random;
      # - each frame overwrites the last line by line, inside a synchronized
      #   update, rather than clearing the screen below and drawing it again,
      #   which flickers with many rows.
      class ProgressBars < Dry::CLI::UI::Widgets::MultiProgress
        # The fewest columns a label is padded to.
        LABEL_WIDTH = 40

        # What each job's row starts with.
        INDENT = "  "

        # The headline's bar color.
        HEADLINE_COLOR = :yellow

        # Rows that have ended and drew a bar while they ran.
        ENDED = %i[done failed].freeze

        # Seconds a finished row stays on a screen too short for every job,
        # at most; see {#visible}.
        LINGER = 1.5

        # Tells the terminal to show a frame only once all of it has arrived.
        # Terminals that do not know these ignore them.
        SYNC_START = "\e[?2026h"
        # Ends the update {SYNC_START} began.
        SYNC_END = "\e[?2026l"

        # Stands between a label's fixed columns and its model.
        MODEL_SEPARATOR = " | "

        # Set by {.for}, to share the colors with whatever draws the models next.
        #
        # @return [ModelColors]
        # @param value [ModelColors]
        attr_writer :model_colors

        # Reaches into the console's private stream, clock and config, which dry-cli-ui offers no other way to pass along.
        #
        # @param console [Dry::CLI::UI::Console] the command's ui, whose stream, clock and settings it draws with
        # @param colors [ModelColors] shared with whatever else draws the models
        # @return [ProgressBars]
        def self.for(console, colors: ModelColors.new)
          new(console.send(:err), clock: console.send(:clock), config: console.send(:config)).tap { it.model_colors = colors }
        end

        # One label per experiment, the dataset and the settings each padded to
        # the widest of its column, so that every model starts in one column:
        # `[01-bookkeeping-cfo]  effort=low t=0.2 | moonshotai/kimi-k3`.
        #
        # @param runs [Array<Actions::Experiment>]
        # @return [Array<String>] in the order given
        def self.labels(runs)
          datasets = runs.map { "[#{it.dataset}]" }
          dataset_width = datasets.map(&:length).max
          settings_width = runs.map { it.model.label.length }.max
          runs.zip(datasets).map do |run, dataset|
            "#{dataset.ljust(dataset_width)}  #{run.model.label.ljust(settings_width)}#{MODEL_SEPARATOR}#{run.model.id}"
          end
        end

        # Stops drawing while the block runs, so a question can use the screen, then
        # starts again below it. The widget's own position no longer means anything by
        # then, so nothing is overwritten.
        #
        # @yieldreturn [Object]
        # @return [Object] what the block returns
        def pausing
          lock.synchronize { @paused = true }
          yield
        ensure
          lock.synchronize do
            @paused = false
            @drawn = 0
            redraw if live?
          end
        end

        private

        # Overrides `Dry::CLI::UI::Widgets::Multi#label_width`: never under {LABEL_WIDTH}, and with room for the indent.
        #
        # @return [Integer]
        def label_width = [LABEL_WIDTH, title.length, *jobs.map { it.label.length }].max + INDENT.length

        # Overrides `Dry::CLI::UI::Widgets::Multi#rows`: a flat list, each job indented and its model painted.
        #
        # @return [Array<String>] the headline, then one row per job shown
        def rows
          width = label_width
          [headline(width), *visible.map { "#{INDENT}#{painted(row(it, width - INDENT.length))}" }]
        end

        # Paints only what follows {MODEL_SEPARATOR}, leaving the meter's colors alone.
        #
        # @param text [String] a job's row, whose label holds the width it was padded to
        # @return [String] the row with its model in that model's color
        def painted(text)
          text.sub(/(?<=#{Regexp.escape(MODEL_SEPARATOR)})\S+/) { terminal.pastel.public_send(model_colors[it], it) }
        end

        # Stands in for a bar built without {.for}.
        #
        # @return [ModelColors]
        def model_colors = @model_colors ||= ModelColors.new

        # The running jobs and those just finished, in the order declared. The
        # finished get at most half the rows, newest first: when jobs end
        # faster than rows linger, the oldest must not hold the screen.
        # Overrides `Dry::CLI::UI::Widgets::Multi#visible`.
        #
        # @return [Array<Dry::CLI::UI::Widgets::Multi::Job>]
        def visible
          return super unless crowded? && state == :running

          slots = [terminal.height - 2, 0].max
          now = clock.call
          finished = jobs.select { lingering?(it, now) }.max_by(slots / 2) { finished_at(it) }
          jobs & (finished + jobs.select { it.state == :running }.first(slots - finished.size))
        end

        # Whether a finished job still gets its row.
        #
        # @param job [Dry::CLI::UI::Widgets::Multi::Job]
        # @param now [Float] by the clock
        # @return [Boolean]
        def lingering?(job, now) = ENDED.include?(job.state) && now - finished_at(job) < LINGER

        # Derived, since a job records when it started and how long it took.
        #
        # @param job [Dry::CLI::UI::Widgets::Multi::Job] one that has ended
        # @return [Float] by the clock
        def finished_at(job) = job.started + job.seconds

        # Overrides `Dry::CLI::UI::Widgets::Multi#redraw`, which clears the screen below
        # first and flickers with many rows; clears only when the frame got shorter.
        #
        # @return [void]
        def redraw
          return if @paused

          drawn = rows
          cursor = terminal.cursor
          up = @drawn.positive? ? cursor.up(@drawn) : ""
          lines = drawn.map { "\r#{it}#{cursor.clear_line_after}\n" }.join
          below = drawn.size < @drawn ? cursor.clear_screen_down : ""
          terminal.print("#{SYNC_START}#{up}#{lines}#{below}#{SYNC_END}")
          @drawn = drawn.size
        end

        # Overrides `Dry::CLI::UI::Widgets::Multi#headline`: live, it keeps its bar to the
        # end, in yellow, with the time taken in place of the ETA.
        #
        # @param width [Integer] the columns its title is padded to
        # @return [String]
        def headline(width)
          return super unless live?

          finished = state != :running
          bar = full_meter(current, total, started, HEADLINE_COLOR, counts, (@seconds if finished))
          "#{glyph(state)} #{title.ljust(width)} #{bar}#{finished ? noted(headline_note) : stopping}"
        end

        # Overrides `Dry::CLI::UI::Widgets::Multi#row`, so that a finished bar stays full
        # instead of turning into a one-line summary.
        #
        # @param job [Dry::CLI::UI::Widgets::Multi::Job]
        # @param width [Integer] the columns its label is padded to
        # @return [String]
        def row(job, width)
          return super unless ENDED.include?(job.state) && !spinner?(job) && live?

          handle = job.handle
          bar = full_meter(handle.current, handle.total, job.started, handle.color, handle.counts, job.seconds.to_f)
          "#{glyph(job.state)} #{job.label.ljust(width)} #{bar}#{noted(note(job))}"
        end

        # {#meter}, with the time taken in place of the ETA once seconds are known.
        #
        # @param done [Integer]
        # @param all [Integer, nil]
        # @param since [Float] when the work started, by the clock
        # @param color [Symbol, nil] the bar's own color, if any
        # @param tally [Hash{Symbol => Integer}, nil] units by outcome
        # @param seconds [Float, nil] the time taken; nil while the work runs
        # @return [String]
        def full_meter(done, all, since, color, tally, seconds)
          return meter(done, all, since, color, tally) if seconds.nil?

          took = Dry::CLI::UI::Duration.format(seconds)
          Dry::CLI::UI::Widgets::Progress.meter(terminal.pastel,
            config,
            done:        done,
            all:         all,
            columns:     bar_columns,
            eta:         took,
            color:       color,
            counts:      tally,
            count_width: count_width).sub("ETA #{took}", "in #{took}")
        end
      end
    end
  end
end
