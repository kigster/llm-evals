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

        # @param result [Results::RunResult]
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
