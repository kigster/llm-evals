# frozen_string_literal: true

module LLM
  module Evals
    module Stats
      # What one call cost, as the provider counted it. Summed over a run.
      #
      # @!attribute [r] input_tokens
      #   @return [Integer]
      # @!attribute [r] output_tokens
      #   @return [Integer]
      # @!attribute [r] cost_usd
      #   @return [Float] in US dollars
      Usage = Data.define(:input_tokens, :output_tokens, :cost_usd) do
        # The start of a sum, and the usage of a reply that never reached a provider.
        #
        # @return [Usage] zero of everything
        def self.zero = new(input_tokens: 0, output_tokens: 0, cost_usd: 0.0)

        # Reads a Hash with Symbol or String keys, missing keys as zero.
        #
        # @param hash [Hash, Usage, nil]
        # @return [Usage]
        def self.from(hash)
          return hash if hash.is_a?(Usage)
          return zero if hash.nil?

          h = hash.transform_keys(&:to_sym)
          new(input_tokens: h.fetch(:input_tokens, 0).to_i,
            output_tokens: h.fetch(:output_tokens, 0).to_i,
            cost_usd: h.fetch(:cost_usd, 0.0).to_f)
        end

        # Adds field by field, which is how a run's usage is totalled.
        #
        # @param other [Usage]
        # @return [Usage]
        def +(other)
          with(input_tokens: input_tokens + other.input_tokens,
            output_tokens: output_tokens + other.output_tokens,
            cost_usd: cost_usd + other.cost_usd)
        end
      end
    end
  end
end
