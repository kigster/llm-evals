# frozen_string_literal: true

module LLM
  module Evals
    class Config
      # One contender per effort and temperature a model's settings list.
      class ContenderBuilder
        # @param defaults [Hash{String => Object}] under the entry's own settings
        # @param overrides [Hash{String => Object}] over them; nil entries are ignored
        def initialize(defaults:, overrides:)
          @defaults = defaults
          @overrides = overrides.compact
        end

        # @param model [String]
        # @param entry [Hash{String => Object}] the model's settings in the file
        # @param provider [Symbol, nil]
        # @return [Array<Contender>]
        def call(model, entry = {}, provider: nil)
          settings = @defaults.merge(entry).merge(@overrides)
          Array(settings["effort"]).product(Array(settings["temperature"])).map do |effort, temperature|
            Contender.new(model:, effort: effort.to_s, temperature:, max_tokens: Integer(settings["max_tokens"]), provider:)
          end
        end
      end
    end
  end
end
