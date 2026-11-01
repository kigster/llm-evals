# frozen_string_literal: true

module LLM
  module Evals
    module Providers
      # Every model OpenRouter serves, through RubyLLM, because Braintrust
      # traces RubyLLM calls (tokens, latency, cost) and not raw HTTP. Claims
      # every id no other provider does, so it is always asked last.
      class OpenRouter < Base
        # The model list, which {#catalog} reads.
        URL = "https://openrouter.ai/api/v1/models"
        # The environment variable holding the API key.
        KEY = "OPENROUTER_API_KEY"

        # OpenRouter's reasoning.effort values.
        EFFORTS = %w[none minimal low medium high xhigh max].freeze

        # Overrides {Base#name}, whose dasherizing would say "open-router".
        #
        # @return [String] "openrouter"
        def name = "openrouter"
        # Overrides {Base#request_type}: chat completions.
        #
        # @return [Symbol] `:prompt`
        def request_type = :prompt
        # Overrides {Base#request_type_description}.
        #
        # @return [String]
        def request_type_description = "a chat completion: system and user text in, text out"
        # Overrides {Base#env_keys}.
        #
        # @return [Array<String>] just {KEY}
        def env_keys = [KEY]
        # Overrides {Base#efforts} with {EFFORTS}, OpenRouter's own list.
        #
        # @return [Array<String>]
        def efforts = EFFORTS

        # Reads the list without credentials.
        #
        # @return [Array<String>] every id OpenRouter lists
        # @raise [Error] when the list cannot be read
        # @raise [KeyError] when the body has no `data`, or an entry no `id`
        def catalog = Catalog.fetch(URL).fetch("data").map { it.fetch("id") }

        # Points RubyLLM at OpenRouter. Requires it here, not at load, so a
        # suite that never reaches OpenRouter never needs the gem.
        #
        # @param app_name [String] what RubyLLM tells OpenRouter the caller is
        # @return [void]
        # @raise [MissingDependency] when the ruby_llm gem is absent
        def setup!(app_name:)
          LLM::Evals.optional!("ruby_llm", needed_for: "calling models through OpenRouter")
          RubyLLM.configure do |config|
            config.openrouter_api_key = ENV.fetch(KEY, nil)
            config.openrouter_app_name = app_name
            config.max_retries = 0 # {Throttle} retries, in step with the limits
          end
        end

        # Only classifies the errors RubyLLM and Faraday raise; anything else is final.
        #
        # @param error [StandardError] what a call raised
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
        # @param error [StandardError] what a call raised
        # @return [Numeric, nil] the seconds to wait, when the error carries a usable header
        def retry_after(error)
          value = error.respond_to?(:response) && error.response&.response_headers&.[]("retry-after")
          Float(value, exception: false) if value
        end

        # Sends one chat through RubyLLM, passing on only the settings the model has.
        #
        # @param model [Models::Model] the model and settings to call
        # @param system [String, nil] the system prompt, if any
        # @param user [String] the user prompt
        # @param json [Boolean] asks for `response_format: json_object`
        # @return [Results::ProviderResponse] text, plus the tokens and the cost OpenRouter billed
        # @raise [MissingDependency] when the ruby_llm gem is absent
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
