# frozen_string_literal: true

module LLM
  module Evals
    module Models
      # One model at one setting, reached through its provider. Adapters call
      # {#complete}; the settings an experiment is named by are read here.
      class Model
        # The settings every provider understands; a provider may accept more.
        SETTINGS = %i[effort temperature max_tokens].freeze

        attr_reader :id, :provider, :settings

        # @!attribute [r] id
        #   The model id as the lineup names it, with any provider prefix.
        #   @return [String]

        # @!attribute [r] provider
        #   What answers the calls.
        #   @return [Providers::Base]

        # @!attribute [r] settings
        #   Frozen; effort, temperature and max_tokens, and whatever else a provider accepts.
        #   @return [Hash{Symbol => Object}]

        # @param id [String] the model id as the lineup names it, e.g. "anthropic/claude-haiku-5.5"
        # @param provider [Providers::Base] what answers {#complete}
        # @param settings [Hash{Symbol => Object}] effort, temperature, max_tokens; nil leaves the model's default
        # @param throttle [Throttle] what every call passes through; share one to share its limits
        def initialize(id:, provider:, settings: {}, throttle: Throttle.new)
          @id = id
          @provider = provider
          @settings = settings.transform_keys(&:to_sym).freeze
          @throttle = throttle
        end

        # @return [String, nil] reasoning effort; nil sends none
        def effort = settings[:effort]

        # @return [Float, nil] sampling temperature; nil sends none
        def temperature = settings[:temperature]

        # @return [Integer, nil] output token cap
        def max_tokens = settings[:max_tokens]

        # @return [String] the id without the provider's prefix, as the provider's API knows it
        def name = provider.model_name(id)

        # @return [String] "provider:id", unique where two providers render the same id
        def key = "#{provider.name}:#{id}"

        # One call. Transport failures raise; they are the run's errors, not the model's.
        #
        # @param system [String, nil] the system prompt
        # @param user [String] the user prompt
        # @param json [Boolean] ask the provider for a JSON object reply where it supports that
        # @return [Results::ProviderResponse]
        def complete(user:, system: nil, json: true)
          @throttle.call(self) { provider.complete(self, system: system, user: user, json: json) }
        end

        # One request of typed questions, for a provider of request type `typesafe`.
        #
        # @param state [Object] what the questions are about, as the suite's adapter shaped it
        # @param questions [Hash{String => Hash}] by name: type, instructions, criteria
        # @return [Results::ProviderResponse]
        def ask(state:, questions:)
          @throttle.call(self) { provider.ask(self, state: state, questions: questions) }
        end

        # @return [String] the effort as reports show it; "default" sends none
        def effort_label = effort || "default"

        # @return [Float, String] the temperature as reports show it; "default" sends none
        def temperature_label = temperature.nil? ? "default" : temperature

        # @return [String] e.g. "effort=low t=0.2"
        def label = "effort=#{effort_label} t=#{temperature_label}"

        # How an experiment's name starts.
        #
        # @return [String] e.g. "anthropic/claude-haiku-5.5 effort=low t=0.2"
        def to_s = "#{id} #{label}"
      end
    end
  end
end
