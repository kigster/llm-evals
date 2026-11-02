# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Runs the experiments side by side, a progress bar each. What would print
      # as a warning meanwhile, failed cases included, goes to the warnings instead.
      class ExperimentPool
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
        # @return [Results::RunOutcome]
        def call(runs, concurrency:, budget: nil)
          summaries = Array.new(runs.size)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @warnings.capture { bars(runs, summaries, concurrency, budget) }
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
        # @param budget [Actions::ErrorBudget, nil]
        # @return [void]
        def bars(runs, summaries, concurrency, budget)
          ProgressBars.for(@console, colors: @colors).run("Running #{runs.size} experiment#{"s" unless runs.size == 1}",
            concurrent: concurrency.zero? || concurrency) do |multi|
            labels = ProgressBars.labels(runs)
            runs.each_with_index do |run, index|
              multi.progress(labels[index], total: run.cases.size) do |bar|
                next if budget&.spent?

                summaries[index] = run.run(stop: -> { budget&.spent? },
                  on_case: lambda { |result|
                    budget&.record(result)
                    bar.advance(as: result.errored? ? :failed : :ok)
                  })
              end
            end
          end
        end
      end
    end
  end
end
