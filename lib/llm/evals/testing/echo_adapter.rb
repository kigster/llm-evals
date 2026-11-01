# frozen_string_literal: true

module LLM
  module Evals
    module Testing
      # The smallest honest adapter: sends the case's input as the user
      # prompt, parses the reply as a JSON object, and reports a reply that
      # is not one as the model's failure. The toy suite runs on it, and a
      # new suite can start from it.
      class EchoAdapter < Actions::Adapter
        SYSTEM = "Answer with a single JSON object and nothing else."
        FENCE = /\A```(?:json)?\s*|\s*```\z/

        # @param kase [Datasets::Case]
        # @param model [Models::Model]
        # @return [Results::Reply]
        def call(kase, model:)
          provider_response = model.complete(system: SYSTEM, user: kase.input, json: true)
          output = JSON.parse(provider_response.text.strip.gsub(FENCE, ""))
          return Results::Reply.new(error: "reply is not a JSON object", raw: provider_response.text, usage: provider_response.usage) unless output.is_a?(Hash)

          Results::Reply.new(output: output, raw: provider_response.text, usage: provider_response.usage)
        rescue JSON::ParserError
          Results::Reply.new(error: "reply is not JSON", raw: provider_response.text, usage: provider_response.usage)
        end
      end
    end
  end
end
