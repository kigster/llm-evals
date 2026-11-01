# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # One case, run once: what came back and what it scored. `reply` is nil
      # when the adapter raised, and `error` then holds the message.
      #
      # @!attribute [r] experiment
      #   @return [Actions::Experiment, Render::Reports::JSON::SavedExperiment] what ran it; the latter when read from a snapshot
      # @!attribute [r] case
      #   @return [Datasets::Case] the case that ran
      # @!attribute [r] reply
      #   @return [Reply, nil] what the adapter returned; nil when it raised
      # @!attribute [r] score
      #   @return [Score, nil] what the reply scored; nil when there is nothing to score
      # @!attribute [r] duration
      #   @return [Float] seconds this case took
      # @!attribute [r] error
      #   @return [String, nil] the message of what the adapter raised
      RunResult = Data.define(:experiment, :case, :reply, :score, :duration, :error) do
        # Only `experiment` and `case` are required, since a failed run has little else.
        #
        # @param experiment [Actions::Experiment, Render::Reports::JSON::SavedExperiment] what ran it
        # @param case [Datasets::Case] the case that ran
        # @param reply [Reply, nil] what the adapter returned
        # @param score [Score, nil] what the reply scored
        # @param duration [Float] seconds this case took
        # @param error [String, nil] the message of what the adapter raised
        def initialize(experiment:, case:, reply: nil, score: nil, duration: 0.0, error: nil) = super

        # @return [Boolean] whether the adapter raised rather than answered
        def failed? = !error.nil?

        # @return [Boolean] whether the case went wrong, by raising or by a reply the model failed
        def errored? = failed? || reply&.error? == true
      end
    end
  end
end
