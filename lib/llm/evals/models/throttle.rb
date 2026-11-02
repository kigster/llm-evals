# frozen_string_literal: true

require "limiter"

module LLM
  module Evals
    module Models
      # Every model call passes through here, in one process, whatever the -j and
      # -p. A call waits for each limit that matches it, narrowest first, so a
      # slot on the shared limit is not spent while the model's own is still shut.
      # Limits are keyed "openrouter", "openrouter/anthropic" and
      # "openrouter/anthropic/claude-fable-5".
      #
      # RubyLLM's retries are off, since they neither pass through the limits nor
      # tell other threads. A call the provider says may succeed later is retried
      # here: it shuts its vendor for every thread, for as long as `Retry-After`
      # says, or for a growing delay when it says nothing. The number of attempts
      # is bounded, and so is the wait, so that a run ends with errors and not at all.
      class Throttle
        # One `rate_limit`: the first `burst` calls of the run go at once, then
        # `per_minute`, evenly spaced. A burst is spent once and never refills, so
        # this is a head start and not a token bucket.
        class Limit
          # @param burst [Integer] calls let through at once, before any spacing
          # @param per_minute [Integer] the evenly spaced rate after that
          def initialize(burst:, per_minute:)
            @burst = burst
            @queue = Limiter::RateQueue.new(per_minute, interval: 60, balanced: true)
            @lock = Mutex.new
          end

          # Blocks until this call may go.
          #
          # @return [void]
          def acquire
            free = @lock.synchronize { (@burst -= 1) >= 0 }
            @queue.shift unless free
          end
        end

        # Tries of one call, the first included, before its error stands.
        MAX_ATTEMPTS = 5
        # The longest growing delay, in seconds, when a provider asks for none.
        MAX_BACKOFF = 30

        # A provider asking for longer than this has really said no.
        MAX_PAUSE = 300

        # The fiber-local key holding the seconds this thread has waited here.
        WAITED = :llm_evals_throttle_waited

        # Runs the block and says how long it spent waiting here, so that latency
        # measures the model and not this lineup's limits. Waits are counted per
        # thread, so those of threads an adapter starts itself are not seen.
        #
        # @yieldreturn [Object]
        # @return [Array(Object, Float)] the block's value, and the seconds waited on this thread
        def self.measure
          before = Thread.current[WAITED].to_f
          value = yield
          [value, Thread.current[WAITED].to_f - before]
        end

        # @param limits [Hash{String => Limit}] by scope
        # @param sleeper [#call] takes seconds
        def initialize(limits = {}, sleeper: method(:sleep))
          @limits = limits
          @sleeper = sleeper
          @paused_until = Hash.new(0.0)
          @lock = Mutex.new
        end

        # @param model [Model]
        # @yieldreturn [Object] the call itself, and nothing else: a retry runs the
        #   block again, so it must be safe to repeat
        # @return [Object] the block's value
        # @raise [StandardError] what the call raised, when it cannot or may not be retried
        def call(model)
          vendor = vendor_scope(model)
          attempts = 1
          begin
            waiting { admit(model, vendor) }
            yield
          rescue StandardError => e
            delay = delay(model.provider, e, attempts)
            raise if delay.nil?

            pause(vendor, delay)
            attempts += 1
            retry
          end
        end

        private

        # Waits out the vendor's pause, then every limit, narrowest first.
        #
        # @param model [Model] the model being called
        # @param vendor [String] the scope a pause would shut
        # @return [void]
        def admit(model, vendor)
          hold(vendor)
          scopes(model).reverse_each { @limits[it]&.acquire }
        end

        # @param model [Model] the model being called
        # @return [Array<String>] "p", "p/vendor", "p/vendor/model"; "p", "p/model" for a provider with no vendors
        def scopes(model)
          parts = model.name.split("/")
          (0..parts.size).map { [model.provider.name, *parts.first(it)].join("/") }
        end

        # What a retryable failure shuts: the vendor, or the whole provider when it has no vendors.
        #
        # @param model [Model] the model being called
        # @return [String] the scope
        def vendor_scope(model) = scopes(model)[model.name.include?("/") ? 1 : 0]

        # @param provider [Providers::Base] says whether the error is retryable, and how long it asked
        # @param error [StandardError] what the call raised
        # @param attempts [Integer] tries so far, this one included
        # @return [Numeric, nil] seconds to wait before another attempt; nil to give up
        def delay(provider, error, attempts)
          return unless attempts < MAX_ATTEMPTS && provider.retryable?(error)

          asked = provider.retry_after(error)
          return [2**(attempts - 1), MAX_BACKOFF].min if asked.nil?

          asked unless asked > MAX_PAUSE
        end

        # Shuts a scope for every thread, never shortening a pause already in force.
        #
        # @param scope [String] the scope to shut
        # @param seconds [Numeric] how long from now
        # @return [void]
        def pause(scope, seconds)
          @lock.synchronize { @paused_until[scope] = [@paused_until[scope], now + seconds].max }
        end

        # Sleeps until a scope is open, checking again in case another thread extended the pause.
        #
        # @param scope [String] the scope to wait on
        # @return [void]
        def hold(scope)
          while (left = @lock.synchronize { @paused_until[scope] } - now).positive?
            @sleeper.call(left)
          end
        end

        # Adds the time the block takes to this thread's total, even when it raises.
        #
        # @yield the wait to measure
        # @yieldreturn [Object]
        # @return [Object] the block's value
        def waiting
          started = now
          yield
        ensure
          Thread.current[WAITED] = Thread.current[WAITED].to_f + (now - started)
        end

        # A clock that wall-clock changes cannot move.
        #
        # @return [Float] monotonic seconds
        def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
