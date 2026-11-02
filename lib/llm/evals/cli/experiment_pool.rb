# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Runs the experiments side by side, a progress bar each. What would print
      # as a warning meanwhile, failed cases included, goes to the warnings instead.
      class ExperimentPool
        # What can halt a run: the lineup's budget, which ends it, and the streak,
        # which pauses it until the pause says otherwise. Either may be absent.
        #
        # @!attribute [r] budget
        #   @return [Actions::ErrorBudget, nil]
        # @!attribute [r] streak
        #   @return [Actions::ErrorStreak, nil]
        # @!attribute [r] pause
        #   @return [#call, nil] given the streak; answers whether to carry on
        Halts = Data.define(:budget, :streak, :pause) do
          # Waits out a pause first, so a worker acts on the answer.
          #
          # @return [Boolean] whether no new case should start
          def stop?
            streak&.hold
            budget&.spent? || streak&.stopped? || false
          end

          # Counts a finished call. The bars stay still while the question is up.
          #
          # @param result [Results::RunResult]
          # @param widget [ProgressBars]
          # @return [void]
          def record(result, widget)
            budget&.record(result)
            streak&.record(result) { |failures| widget.pausing { pause.call(failures) } }
          end
        end

        # Holds only collaborators; nothing runs until {#call}.
        #
        # @param console [Dry::CLI::UI::Console]
        # @param colors [ModelColors]
        # @param warnings [Results::Warnings]
        def initialize(console:, colors:, warnings:)
          @console = console
          @colors = colors
          @warnings = warnings
        end

        # Returns once every experiment has ended; one the budget stopped before it began has no summary.
        #
        # @param runs [Array<Actions::Experiment>]
        # @param concurrency [Integer] experiments at once; 0 runs them all together
        # @param budget [Actions::ErrorBudget, nil] stops the run once spent
        # @param streak [Actions::ErrorStreak, nil] pauses the run on a streak of failures
        # @param pause [#call, nil] given the streak; answers whether to carry on
        # @return [Results::RunOutcome]
        def call(runs, concurrency:, budget: nil, streak: nil, pause: nil)
          summaries = Array.new(runs.size)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @warnings.capture { bars(runs, summaries, concurrency, Halts.new(budget:, streak:, pause:)) }
          seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          summaries.compact.each { |s| s.errors.each { @warnings.record("[#{s.name}] #{it}") } }
          Results::RunOutcome.new(summaries: summaries.compact, seconds:)
        end

        private

        # Draws a bar per run and fills summaries by position, so they keep the order
        # given whichever finishes first. A run the budget stopped before it began leaves a nil.
        #
        # @param runs [Array<Actions::Experiment>]
        # @param summaries [Array<Actions::Experiment::Summary, nil>] written in place, one slot per run
        # @param concurrency [Integer] experiments at once; 0 runs them all together
        # @param halts [Halts]
        # @return [void]
        def bars(runs, summaries, concurrency, halts)
          widget = ProgressBars.for(@console, colors: @colors)
          widget.run("Running #{runs.size} experiment#{"s" unless runs.size == 1}",
            concurrent: concurrency.zero? || concurrency) do |multi|
            labels = ProgressBars.labels(runs)
            runs.each_with_index do |run, index|
              multi.progress(labels[index], total: run.cases.size) do |bar|
                next if halts.stop?

                summaries[index] = run.run(stop: -> { halts.stop? },
                  on_case: lambda { |result|
                    bar.advance(as: result.errored? ? :failed : :ok)
                    halts.record(result, widget)
                  })
              end
            end
          end
        end
      end
    end
  end
end
