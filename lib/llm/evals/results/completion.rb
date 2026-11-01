# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # What a {Models::Model} returns from one call: the text, what it cost, and the
      # provider's raw response for an adapter that needs more than the text.
      Completion = Data.define(:text, :usage, :raw) do
        def initialize(text:, usage: Stats::Usage.zero, raw: nil) = super(text: text.to_s, usage: Stats::Usage.from(usage), raw: raw)
      end
    end
  end
end
