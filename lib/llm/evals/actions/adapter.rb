# frozen_string_literal: true

module LLM
  module Evals
    module Actions
      # What a suite implements to run one case: everything the model sees, and
      # everything done to its answer before it is scored. An adapter never
      # scores; that is the {Scoring::Scorer}'s, and keeping them apart is what lets one
      # suite compare prompts and another compare models with the same runner.
      #
      # @abstract Subclass and override {#call}.
      class Adapter
        # Called once per experiment before its cases run; load what the
        # dataset shares (a schema, a flow definition) here, outside the
        # threads. Experiments on other datasets may run at the same time, so
        # an adapter that keeps what it loads is registered by its class, to
        # get one instance per experiment (see {Runtime::Configuration#adapter}).
        #
        # @param _dataset [String] the dataset's name
        # @return [void]
        def prepare(_dataset) = nil

        # Runs one case against one model.
        #
        # @param kase [Datasets::Case] the case to run
        # @param model [Models::Model] the model at the setting under test
        # @return [Results::Reply] with `error:` set when the model failed to answer; raise for a transport failure
        # @raise [NotImplementedError] until a subclass overrides it
        def call(kase, model:)
          raise NotImplementedError, "#{self.class}#call(kase, model:) must return an LLM::Evals::Results::Reply"
        end

        # What the scorer needs to know about a case beyond the case itself: a
        # schema, field types, the prompt. Passed to {Scoring::Scorer#call} as `context:`.
        #
        # @param _kase [Datasets::Case] the case about to be scored
        # @return [Hash]
        def context(_kase) = {}

        # Offline checks of a dataset's shared files. `llm-evals verify` prints them.
        #
        # @param _dataset [String] the dataset's name
        # @return [Array<String>] problems; empty when the dataset is sound
        def verify(_dataset) = []

        # Recorded with each Braintrust experiment, e.g. which prompt version ran.
        #
        # @return [Hash]
        def metadata = {}
      end
    end
  end
end
