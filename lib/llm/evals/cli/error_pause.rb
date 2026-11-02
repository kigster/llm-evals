# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Says what is failing and asks whether to carry on. With nobody to ask, as
      # in CI, it stops: nothing suggests the remaining calls would fare better.
      class ErrorPause
        # The question put to the user.
        QUESTION = "Keep running?"

        # The most error messages shown; the rest are only counted.
        MESSAGES = 3

        # The most names listed per dimension; the rest are only counted.
        NAMES = 5

        # How much of one message is shown.
        MESSAGE_WIDTH = 300

        # @param console [Dry::CLI::UI::Console] asks the question
        # @param notice [#call] given the box's level and text
        # @param runs [Array<Actions::Experiment>] the whole run
        # @param yes [Boolean] carry on without asking
        # @param interactive [Boolean] whether anyone can answer
        def initialize(console:, notice:, runs:, yes: false, interactive: $stdin.tty?)
          @console = console
          @notice = notice
          @runs = runs
          @yes = yes
          @interactive = interactive
        end

        # @param failures [Array<Results::RunResult>] the streak
        # @return [Boolean] whether the run should carry on
        def call(failures)
          @notice.call(:error, describe(Actions::ErrorDiagnosis.new(failures:, runs: @runs), failures.size))
          return true if @yes
          return false unless @interactive

          @console.confirm(QUESTION, default: false)
        end

        private

        # @param diagnosis [Actions::ErrorDiagnosis]
        # @param count [Integer] the failures in the streak
        # @return [String] the box's text
        def describe(diagnosis, count)
          scopes = { "Models" => diagnosis.models, "Datasets" => diagnosis.datasets, "Cases" => diagnosis.cases }
          lines = ["#{count} calls in a row failed. Paused: no new calls will start.", *errors(diagnosis.messages)]
          lines.concat(scopes.map { |name, scope| "#{name}: #{extent(scope)}" })
          lines << "The others have not failed so far, or have not run yet." unless scopes.values.all?(&:all?)
          lines.join("\n")
        end

        # @param messages [Array<Array(String, Integer)>]
        # @return [Array<String>]
        def errors(messages)
          shown = messages.first(MESSAGES).map { |message, count| "#{count} x #{message[0, MESSAGE_WIDTH]}" }
          hidden = messages.size - shown.size
          if hidden.positive?
            [*shown, "and #{hidden} other #{hidden == 1 ? "error" : "errors"}"]
          else
            shown
          end
        end

        # @param scope [Actions::ErrorDiagnosis::Scope]
        # @return [String] "all 3 affected", or how many and which
        def extent(scope)
          return "all #{scope.total} affected" if scope.all?

          hidden = scope.failed.size - NAMES
          names = scope.failed.first(NAMES).join(", ")
          "#{scope.failed.size} of #{scope.total} affected: #{names}#{" and #{hidden} more" if hidden.positive?}"
        end
      end
    end
  end
end
