# frozen_string_literal: true

require "fileutils"

module LLM
  module Evals
    module CLI
      # The options shared by the commands that call a model. Settings resolve
      # flag first, then the config entry, then .llm-evals.config.yml's defaults.
      #
      # Every column that is not a metric is the gem's; the metric columns,
      # their glossary and the ranking come from the suite's {Scoring::Scorer#metrics}.
      class ModelCommand < Command
        include Formatting

        # Gives each subclass the model flags, since dry-cli starts every subclass with no options.
        #
        # @param subclass [Class<ModelCommand>]
        # @return [void]
        def self.inherited(subclass)
          super
          ModelOptions.apply(subclass)
        end

        # The run every model command makes; subclasses add what prints per run
        # through {#details}.
        #
        # @param models [Array<String>] as given to -m, possibly comma-separated
        # @param dataset [Array<String>] as given to -d, possibly comma-separated
        # @param dry_run [Boolean] print the matrix and spend nothing
        # @param yes [Boolean] keep running through a streak of failures without asking
        # @param options [Hash{Symbol => Object}] the other parsed flags
        # @return [void]
        # @raise [Error] when nothing can run, once the error budget is spent, or when told to stop
        def call(models:, dataset:, dry_run:, yes: false, **options)
          config = lineup(options)
          weigh(config)
          trackers = TrackerResolver.new(configuration:, config:, options:, err:)
          planner = RunPlanner.new(configuration:, config:, options:, trackers:)
          contenders = ContenderSelector.new(config:, providers:, warnings:).call(models, options)
          datasets = planner.datasets(dataset)
          return matrix(datasets, contenders) if dry_run

          setup!(contenders, trackers)
          runs = planner.experiments(datasets, contenders)
          budget = config.error_budget
          streak = Actions::ErrorStreak.new
          pause = ErrorPause.new(console: ui, runs:, yes:, notice: ->(level, text) { status_box(level, text, stream: err) })
          outcome = ExperimentPool.new(console: ui, colors: model_colors, warnings:)
                                  .call(runs, concurrency: planner.concurrency, budget:, streak:, pause:)
          record = RunRecord.new(command: invocation.action.to_s,
            cli: { models:, dataset:, **options },
            config:,
            planner:,
            trackers:,
            providers:,
            contenders:,
            datasets:,
            runs:,
            seconds: outcome.seconds)
          report(outcome.summaries,
            output:      options[:output],
            open:        options[:open],
            scores:      options[:scores],
            format:      options[:format],
            config:,
            options:,
            run_options: record.to_h) { details(it) }
          raise Error, budget.reason if budget&.spent?
          raise Error, streak.reason if streak.stopped?
        end

        private

        # What prints before the leaderboard; nothing, unless a subclass says.
        #
        # @param _summaries [Array<Actions::Experiment::Summary>]
        # @return [void]
        def details(_summaries) = nil

        # A file named by --config may use the names of the suite's providers.
        #
        # @param options [Hash] the parsed flags
        # @return [Config] the lineup: --config, else the suite's
        def lineup(options) = options[:config] ? Config.new(File.expand_path(options[:config]), providers:) : configuration.lineup

        # The suite's, which every lineup and saved report is read against.
        #
        # @return [Providers::Registry]
        def providers = configuration.providers

        # The suite's; it supplies the metrics until a saved snapshot replaces them.
        #
        # @return [Scoring::Scorer]
        def scorer = configuration.scorer

        # The saved snapshot's once reporting has begun, so a report shows what was saved.
        #
        # @return [Array<Scoring::Metric>]
        def metrics = @report_metrics || scorer.metrics

        # Reads the file's weights before anything is spent, so a bad one fails
        # the run rather than the report at its end.
        #
        # @param config [Config]
        # @return [Scoring::WeightedScore, nil] nil when the file sets none
        # @raise [Error] on a bad weight
        def weigh(config)
          config.validate!
          weights = config.score_weights
          @weighted = weights.empty? ? nil : Scoring::WeightedScore.new(weights, metrics: metrics.map(&:name))
        end

        # Env, the tracker's gems and key, hooks, provider clients, then the catalogs.
        #
        # @param contenders [Array<Models::Contender>]
        # @param trackers [TrackerResolver]
        # @return [void]
        # @raise [Error] when a needed variable or gem is missing
        def setup!(contenders, trackers)
          configuration.runtime.setup!(providers: providers.used_by(contenders), tracker: trackers.remote)
          providers.verify!(contenders)
        end

        # What -n prints: every experiment that would run, and where the
        # refusals went, if there were any.
        #
        # @param datasets [Array<String>]
        # @param contenders [Array<Models::Contender>]
        # @return [void]
        def matrix(datasets, contenders)
          rows = datasets.product(contenders).map { |name, c| [name, c.model, c.effort, c.temperature, c.max_tokens] }
          table(rows, header: %w[dataset model effort temp max_tokens])
          save_warnings
        end

        # Filled by the selector and the pool, and written out only by {#save_warnings}.
        #
        # @return [Results::Warnings] what this command has held back from the screen
        def warnings = @warnings ||= Results::Warnings.new

        # Prints what the block writes, then the leaderboard, its glossary and
        # the scores, when the run's display is the terminal; see {ReportDispatcher}.
        #
        # @param summaries [Array<Actions::Experiment::Summary>]
        # @param output [String, nil] what -o was given: nil, "-", "" for the default file, or a path
        # @param open [Boolean]
        # @param scores [Boolean] also print every experiment by score
        # @param format [String, nil] `tui`, `html` or `json`
        # @param config [Config]
        # @param options [Hash] the parsed flags
        # @param run_options [Hash] what the saved report says about its run; see {RunRecord#to_h}
        # @param details [Proc, nil] prints what comes before the leaderboard, given the summaries shown
        # @return [void]
        def report(summaries, config:, options:, run_options:, output:, open:, scores: false, format: nil, &details)
          dispatcher = report_dispatcher(config, options)
          # A run that also writes the page opens that, not a second window on the tracker.
          open_tracker = open && dispatcher.display(format) == "tui"
          dispatcher.call(summaries, metrics:, weighted_score: @weighted, run_options:, output:, open:, format:) do |report|
            @report_metrics = report.metrics
            @weighted = report.weighted_score
            terminal_report(report.summaries, output:, open: open_tracker, scores:, totals_mode: options[:totals], run_options:) do |shown|
              details&.call(shown)
            end
          end
        end

        # Hands over the command's streams only through a {ReportDispatcher::Console},
        # so that no output ever sees the command.
        #
        # @param config [Config]
        # @param options [Hash] the parsed flags
        # @return [ReportDispatcher]
        def report_dispatcher(config, options)
          ReportDispatcher.new(config:,
            options:,
            providers:,
            runtime: configuration.runtime,
            suite: configuration.name,
            invocation:,
            console: ReportDispatcher::Console.new(out:,
              browser: configuration.runtime,
              save_warnings: method(:save_warnings),
              status: ->(level, text) { status_box(level, text, stream: err) }))
        end

        # Draws the terminal view, says where a report file went, saves the warnings,
        # and opens the best experiment on its tracker.
        #
        # @param summaries [Array<Actions::Experiment::Summary>]
        # @param output [String, nil] what -o was given
        # @param open [Boolean] open the best experiment's tracker page
        # @param scores [Boolean] also print every experiment by score
        # @param totals_mode [String] `overall`, `variant` or `both`
        # @param run_options [Hash] what the call statistics are read from
        # @param details [Proc, nil] prints what comes before the statistics, given the summaries shown
        # @return [void]
        def terminal_report(summaries, output:, open:, scores:, totals_mode:, run_options:, &details)
          terminal = LLM::Evals::Render::Reports::Terminal.new(invocation:, writing_to: method(:writing_to), leaderboard: method(:leaderboard))
          path = terminal.call(summaries:, output:, scores:, totals_mode:) do |shown|
            details&.call(shown)
            stats = LLM::Evals::Render::Reports::CallStatsTable.new(Stats::CallStats.for_run(shown, run_options))
            table(stats.rows, header: LLM::Evals::Render::Reports::CallStatsTable::HEADER, fill: 0)
          end
          status_box(:info, "Report written to #{relative(path)}", stream: err) if path
          save_warnings
          url = summaries.max_by { it.score || -1 }&.permalink
          status_box(:warning, "could not open #{url}", stream: err) if open && url && !configuration.runtime.browse(url)
        end

        # Saves {#warnings}, if there are any, to
        # log/<command>.warnings.<YYYY-MM-DD>.<HHMMSS>.log at the repository
        # root, stamped with the time the process started, and says how many.
        #
        # @return [void]
        def save_warnings
          return if warnings.none?

          stamp = Dry::CLI::UI.started_at.strftime("%Y-%m-%d.%H%M%S")
          path = File.join(Dry::CLI::UI::Invocation.root(Dir.pwd), "log", "#{invocation.action}.warnings.#{stamp}.log")
          FileUtils.mkdir_p(File.dirname(path))
          warnings.save(path)
          count = warnings.count
          status_box(:warning, "#{count} #{count == 1 ? "Warning was" : "Warnings were"} recorded in #{relative(path)}", stream: err)
        end

        # Points the tables and boxes at another stream while the block runs.
        # They keep the screen's width.
        #
        # @param io [IO, Dry::CLI::UI::Report, nil] nil to leave them on the screen
        # @yield with the stream swapped
        # @return [Object] what the block returns
        def writing_to(io)
          return yield if io.nil?

          screen = out
          @screen = screen
          @out = io
          @pastel = nil
          yield
        ensure
          if io
            @out = screen
            @screen = nil
            @pastel = nil
          end
        end

        # A snapshot's metrics may name their own primary; otherwise the scorer's stands.
        #
        # @return [Scoring::Metric]
        def primary = metrics.find(&:primary) || scorer.primary

        # One per command, so the bars and the tables agree.
        #
        # @return [ModelColors]
        def model_colors = @model_colors ||= ModelColors.new

        # Built per call: {#report} swaps the metrics and the weights for those of
        # the saved snapshot, and {#writing_to} swaps the stream, before this runs.
        #
        # @param summaries [Array<Actions::Experiment::Summary>]
        # @param scores [Boolean] also print every experiment by score
        # @param totals_mode [String] `overall`, `variant` or `both`
        # @return [void]
        def leaderboard(summaries, scores: false, totals_mode: "overall")
          standings = Standings.new(metrics:, primary:, weighted: @weighted)
          Leaderboard.new(standings:, table: method(:table), out:, pastel:, colors: model_colors)
                     .call(summaries, scores:, totals_mode:)
        end
      end
    end
  end
end
