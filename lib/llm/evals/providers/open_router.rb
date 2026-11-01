# frozen_string_literal: true

module LLM
  module Evals
    module Providers
      # Every model OpenRouter serves, through RubyLLM, because Braintrust
      # traces RubyLLM calls (tokens, latency, cost) and not raw HTTP. Claims
      # every id no other provider does, so it is always asked last.
      class OpenRouter < Base
        URL = "https://openrouter.ai/api/v1/models"
        KEY = "OPENROUTER_API_KEY"

        # OpenRouter's reasoning.effort values.
        EFFORTS = %w[none minimal low medium high xhigh max].freeze

        def name = "openrouter"
        def request_type = :prompt
        def request_type_description = "a chat completion: system and user text in, text out"
        def env_keys = [KEY]
        def efforts = EFFORTS

        # @return [Array<String>] every id OpenRouter lists
        def catalog = Catalog.fetch(URL).fetch("data").map { it.fetch("id") }

        # Points RubyLLM at OpenRouter. Requires it here, not at load, so a
        # suite that never reaches OpenRouter never needs the gem.
        #
        # @param app_name [String]
        # @return [void]
        def setup!(app_name:)
          LLM::Evals.optional!("ruby_llm", needed_for: "calling models through OpenRouter")
          RubyLLM.configure do |config|
            config.openrouter_api_key = ENV.fetch(KEY, nil)
            config.openrouter_app_name = app_name
            config.max_retries = 0 # {Throttle} retries, in step with the limits
          end
        end

        # @param error [StandardError]
        # @return [Boolean] rate limits, overloads and dropped connections
        def retryable?(error)
          case error
          when RubyLLM::RateLimitError, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError, RubyLLM::OverloadedError,
               Faraday::TimeoutError, Faraday::ConnectionFailed then true
          else false
          end
        end

        # OpenRouter sends the header only when every upstream hinted at it.
        #
        # @param error [StandardError]
        # @return [Numeric, nil]
        def retry_after(error)
          value = error.respond_to?(:response) && error.response&.response_headers&.[]("retry-after")
          Float(value, exception: false) if value
        end

        # @param model [Models::Model]
        # @param system [String, nil]
        # @param user [String]
        # @param json [Boolean] asks for `response_format: json_object`
        # @return [Results::ProviderResponse] text, plus the tokens and the cost OpenRouter billed
        def complete(model, system:, user:, json: true)
          LLM::Evals.optional!("ruby_llm", needed_for: "calling models through OpenRouter")
          chat = RubyLLM.chat(model: model.name, provider: :openrouter, assume_model_exists: true)
          chat.with_instructions(system) if system
          chat.with_temperature(model.temperature) unless model.temperature.nil?
          chat.with_max_output_tokens(model.max_tokens) if model.max_tokens
          chat.with_thinking(effort: model.effort.to_sym) if model.effort
          chat.with_provider_options(response_format: { type: "json_object" }) if json

          message = chat.ask(user)
          Results::ProviderResponse.new(
            text:  message.content.to_s,
            usage: Stats::Usage.new(input_tokens: message.tokens.input.to_i,
              output_tokens: message.tokens.output.to_i,
              cost_usd: message.tokens.reported_cost.to_f),
            raw:   message
          )
        end
      end
    end
  end
end
