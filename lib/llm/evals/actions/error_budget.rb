# frozen_string_literal: true

module LLM
  module Evals
    module Actions
      # How many failed calls a run tolerates, from `errors.abort_after`: at least
      # `total` errors, and, when `percent` is set, at least that share of the
      # calls finished so far. Shared by every experiment's threads, and once
      # spent it stays spent, so a late success cannot restart an aborted run.
      class ErrorBudget
        attr_reader :total, :percent, :errors, :calls

        # @!attribute [r] total
        #   The fewest errors at which the run may abort.
        #   @return [Integer]

        # @!attribute [r] percent
        #   The share of finished calls that must also have failed, from 0 to 100.
        #   @return [Numeric, nil]

        # @!attribute [r] errors
        #   Failed calls so far, counted across every experiment sharing this budget.
        #   @return [Integer]

        # @!attribute [r] calls
        #   Finished calls so far, whether or not they failed.
        #   @return [Integer]

        # @param total [Integer] errors before the run may abort
        # @param percent [Numeric, nil] the share of finished calls that must have failed
        def initialize(total:, percent: nil)
          @total = total
          @percent = percent
          @errors = 0
          @calls = 0
          @spent = false
          @lock = Mutex.new
        end

        # Counts one finished call, and marks the budget spent once both limits are met.
        #
        # @param result [Results::RunResult] the finished call
        # @return [void]
        def record(result)
          @lock.synchronize do
            @calls += 1
            @errors += 1 if result.errored?
            @spent ||= @errors >= total && (percent.nil? || @errors * 100.0 / @calls >= percent)
          end
        end

        # @return [Boolean] whether the run must stop
        def spent? = @lock.synchronize { @spent }

        # @return [String] why the run stopped
        def reason
          limit = percent ? "#{total} errors at #{percent}%" : "#{total} errors"
          "run aborted: #{errors} of #{calls} finished calls failed (errors.abort_after: #{limit}); partial results were kept"
        end
      end
    end
  end
end
