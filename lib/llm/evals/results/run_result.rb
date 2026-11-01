# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # One case, run once: what came back and what it scored. `reply` is nil
      # when the adapter raised, and `error` then holds the message.
      RunResult = Data.define(:experiment, :case, :reply, :score, :duration, :error) do
        def initialize(experiment:, case:, reply: nil, score: nil, duration: 0.0, error: nil) = super

        # @return [Boolean] whether the adapter raised rather than answered
        def failed? = !error.nil?

        # @return [Boolean] whether the case went wrong, by raising or by a reply the model failed
        def errored? = failed? || reply&.error? == true
      end
    end
  end
end
