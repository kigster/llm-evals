# frozen_string_literal: true

module LLM
  module Evals
    module Models
      # One model at one setting: what a single experiment runs. Built by
      # {Config} from the lineup file, or from `-m` on the command line.
      #
      # `provider` is nil for an entry whose id picks its provider, as OpenRouter's
      # do, and the provider's name for a direct provider's entry. It travels with the
      # contender rather than being read back out of the id, so `typesafe/jev-router`
      # (Jev on OpenRouter) and a direct `typesafe/jev-latest` can never be confused.
      #
      # @!attribute [r] model
      #   @return [String] the model id, as the lineup names it
      # @!attribute [r] effort
      #   @return [String, nil] reasoning effort; "default" or nil sends none
      # @!attribute [r] temperature
      #   @return [Numeric, String, nil] sampling temperature; "default" or nil sends none
      # @!attribute [r] max_tokens
      #   @return [Integer, nil] output token cap; nil sends none
      # @!attribute [r] provider
      #   @return [Symbol, nil] a direct provider's name; nil when the id picks the provider
      Contender = Data.define(:model, :effort, :temperature, :max_tokens, :provider) do
        # Gives everything but the model a default, so `-m` needs to name only that.
        #
        # @param model [String] the model id, as the lineup names it
        # @param effort [String, nil] reasoning effort
        # @param temperature [Numeric, String, nil] sampling temperature
        # @param max_tokens [Integer, nil] output token cap
        # @param provider [Symbol, nil] a direct provider's name
        def initialize(model:, effort: "default", temperature: "default", max_tokens: nil, provider: nil) = super

        # @return [Boolean] whether the entry came from a direct provider's section
        def direct? = !provider.nil?

        # @return [String] unique across the lineup: "typesafe:typesafe/jev-latest" for a direct entry
        def key = direct? ? "#{provider}:#{model}" : model

        # The settings as a {Model} takes them: "default" means nil, send nothing.
        #
        # @return [Hash{Symbol => Object}]
        def settings
          { effort:      effort.to_s == "default" || effort.nil? ? nil : effort.to_s,
            temperature: temperature.to_s == "default" || temperature.nil? ? nil : Float(temperature),
            max_tokens:  max_tokens.nil? ? nil : Integer(max_tokens) }
        end
      end
    end
  end
end
