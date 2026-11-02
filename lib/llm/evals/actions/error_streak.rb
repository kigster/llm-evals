# frozen_string_literal: true

module LLM
  module Evals
    module Actions
      # Notices when every call has been failing, and holds the run while someone
      # decides what to do. A bad key or a dead endpoint fails everything, and
      # without this the run spends its whole matrix finding that out. Unlike
      # {ErrorBudget}, which the lineup opts into and which only stops, this is
      # always on and can resume. Shared by every experiment's threads.
      class ErrorStreak
        # Failures in a row, with no success between them, that pause the run.
        LIMIT = 100

        # @param limit [Integer] failures in a row that pause the run
        def initialize(limit: LIMIT)
          @limit = limit
          @failures = []
          @paused = false
          @stopped = false
          @lock = Mutex.new
          @resumed = ConditionVariable.new
        end

        # Counts one finished call. The call that completes a streak is the one
        # that asks; the other workers wait in {#hold}. Calls still in flight
        # while it asks do not count, so one question cannot lead straight to another.
        #
        # @param result [Results::RunResult] the finished call
        # @yieldparam failures [Array<Results::RunResult>] the streak, oldest first
        # @yieldreturn [Boolean] whether the run should carry on
        # @return [void]
        def record(result)
          failures = @lock.synchronize { tally(result) }
          settle { yield failures } if failures
        end

        # Blocks while the run is paused. Workers call it before starting a case.
        #
        # @return [void]
        def hold
          @lock.synchronize { @resumed.wait(@lock) while @paused }
        end

        # @return [Boolean] whether the answer was to stop
        def stopped? = @lock.synchronize { @stopped }

        # @return [String] why the run stopped
        def reason = "run stopped after #{@limit} failed calls in a row; partial results were kept"

        private

        # @param result [Results::RunResult]
        # @return [Array<Results::RunResult>, nil] the streak, once it reaches the limit
        def tally(result)
          return if @paused || @stopped

          result.errored? ? @failures << result : @failures.clear
          return if @failures.size < @limit

          @paused = true
          @failures.dup.tap { @failures.clear }
        end

        # Releases the workers whatever happens: an exception or an interrupt
        # while asking counts as a stop, since nobody said to carry on.
        #
        # @yieldreturn [Boolean] whether the run should carry on
        # @return [void]
        def settle
          carry_on = false
          carry_on = yield
        ensure
          @lock.synchronize do
            @paused = false
            @stopped = !carry_on
            @resumed.broadcast
          end
        end
      end
    end
  end
end
