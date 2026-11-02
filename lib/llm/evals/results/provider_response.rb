# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # What a {Models::Model} returns from one call: the text, what it cost, and the
      # provider's raw response for an adapter that needs more than the text.
      #
      # @!attribute [r] text
      #   @return [String] the model's answer, never nil
      # @!attribute [r] usage
      #   @return [Stats::Usage] what the call cost
      # @!attribute [r] raw
      #   @return [RubyLLM::Message, Hash, nil] the provider's own response: OpenRouter's message, TypeSafe's answers by name
      ProviderResponse = Data.define(:text, :usage, :raw) do
        # Normalizes the text to a String and the usage to {Stats::Usage}.
        #
        # @param text [#to_s] the model's answer
        # @param usage [Stats::Usage, Hash, nil] what the call cost; see {Stats::Usage.from}
        # @param raw [RubyLLM::Message, Hash, nil] the provider's own response
        def initialize(text:, usage: Stats::Usage.zero, raw: nil) = super(text: text.to_s, usage: Stats::Usage.from(usage), raw: raw)
      end
    end
  end
end
