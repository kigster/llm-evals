# frozen_string_literal: true

module LLM
  module Evals
    module Testing
      # A {Models::Model} on a {FakeProvider} of its own, for specs that run an
      # adapter or an {Actions::Experiment} without the CLI.
      class FakeModel < Models::Model
        # @param id [String]
        # @param settings [Hash]
        # @param provider_options [Hash] passed to {FakeProvider#initialize}
        def initialize(id: "fake/echo", settings: { effort: nil, temperature: 0.2, max_tokens: 4096 }, **provider_options)
          super(id: id, provider: FakeProvider.new(**provider_options), settings: settings)
        end
      end
    end
  end
end
