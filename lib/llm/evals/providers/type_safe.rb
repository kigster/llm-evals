# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"

module LLM
  module Evals
    module Providers
      # TypeSafe's own API, which serves Jev as typed questions (noul, choice,
      # score) rather than chat: request type `typesafe`, reached only through
      # a `typesafe:` section, whose ids read "typesafe/<name>". Jev on
      # OpenRouter, `typesafe/jev-router` under `openrouter:`, is a chat model
      # and goes through {OpenRouter}; the contender carries which is meant.
      # A suite's adapter reaches it through {Models::Model#ask}.
      class TypeSafe < Base
        # The namespace of this API's model ids.
        PREFIX = "typesafe/"
        # The model list, which {#catalog} reads; {Client::URL} takes the questions.
        URL = "https://api.typesafe.ai/v1/models"
        # The environment variable holding the API key.
        KEY = "TYPESAFE_API_KEY"

        # TypeSafe bills input tokens only: $0.042 per million for jev-latest
        # and jev-preview (docs.typesafe.ai/models, read 2026-10-14). Output is free.
        USD_PER_INPUT_TOKEN = 0.042 / 1_000_000

        # An answer TypeSafe refused, with its status, for {Models::Throttle} to judge.
        class HTTPError < Error
          attr_reader :status, :retry_after

          # @!attribute [r] status
          #   @return [Integer] the HTTP status code

          # @!attribute [r] retry_after
          #   @return [Float, nil] seconds from the `retry-after` header, when it is numeric

          # Reads the status and hint off the response, and keeps at most 500 characters
          # of the body in the message.
          #
          # @param response [Net::HTTPResponse]
          def initialize(response)
            @status = response.code.to_i
            @retry_after = Float(response["retry-after"], exception: false) if response["retry-after"]
            super("TypeSafe answered #{@status}: #{response.body.to_s[0, 500]}")
          end
        end

        # Overrides {Base#name}.
        #
        # @return [String] "typesafe"
        def name = "typesafe"
        # Overrides {Base#request_type}: only suites declaring `typesafe` admit this.
        #
        # @return [Symbol] `:typesafe`
        def request_type = :typesafe
        # Overrides {Base#request_type_description}.
        #
        # @return [String]
        def request_type_description = "typed questions: noul, choice, score"
        # Overrides {Base#direct?}: reached only through a `typesafe:` section.
        #
        # @return [Boolean] true
        def direct? = true
        # Overrides {Base#prefix}.
        #
        # @return [String] {PREFIX}
        def prefix = PREFIX
        # Overrides {Base#env_keys}.
        #
        # @return [Array<String>] just {KEY}
        def env_keys = [KEY]

        # Jev takes no reasoning effort.
        #
        # @return [Array<String>] always empty
        def efforts = []

        # Overrides {Base#catalog}, with the key as a bearer token.
        #
        # @return [Array<String>] the models, as "typesafe/<name>"
        # @raise [Error] when the list cannot be read
        # @raise [KeyError] when the body has no `models`, or an entry no `name`
        def catalog
          Catalog.fetch(URL, "Authorization" => "Bearer #{ENV.fetch(KEY, nil)}").fetch("models").map { "#{PREFIX}#{it.fetch("name")}" }
        end

        # Prices a call at TypeSafe's input rate; output tokens are counted but free.
        #
        # @param input_tokens [Integer] tokens billed
        # @param output_tokens [Integer] tokens returned, which cost nothing
        # @return [Stats::Usage] with the cost at TypeSafe's input rate
        def usage(input_tokens:, output_tokens: 0)
          Stats::Usage.new(input_tokens: input_tokens, output_tokens: output_tokens, cost_usd: input_tokens * USD_PER_INPUT_TOKEN)
        end

        # Overrides {Base#complete} only to refuse, naming the method to call instead.
        #
        # @param model [Models::Model] the model that was called
        # @param system [String, nil] ignored
        # @param user [String] ignored
        # @param json [Boolean] ignored
        # @return [void] never returns
        # @raise [Error] always: this API answers typed questions; see {#ask}
        def complete(model, system:, user:, json: true) # rubocop:disable Lint/UnusedMethodArgument
          raise Error, "#{model.id}: TypeSafe answers typed questions, not prompts; call Model#ask"
        end

        # One request of typed questions over one state. They run in parallel
        # and cannot see each other's answers.
        #
        # @param model [Models::Model] the model to ask
        # @param state [Object] what the questions are about; any JSON-encodable value
        # @param questions [Hash{String => Hash}] by name: type, instructions, criteria
        # @return [Results::ProviderResponse] `raw` holds the answers by name; `text` is them as JSON
        # @raise [HTTPError] on any status but 2xx
        # @raise [Error] on a missing key, or a 2xx that is not a usable answer
        def ask(model, state:, questions:)
          body = client.ask({ model: model.name, state: state, questions: questions })
          answers = body["answers"]
          tokens = body.fetch("usage", {})
          Results::ProviderResponse.new(text: JSON.generate(answers),
            usage: usage(input_tokens: tokens["input_tokens"].to_i, output_tokens: tokens["output_tokens"].to_i),
            raw: answers)
        end

        # Overrides {Base#retryable?}.
        #
        # @param error [StandardError] what a call raised
        # @return [Boolean] 429, 529 and other server errors, and dropped connections
        def retryable?(error)
          case error
          when HTTPError then error.status == 429 || error.status >= 500
          when Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError then true
          else false
          end
        end

        # Overrides {Base#retry_after}.
        #
        # @param error [StandardError] what a call raised
        # @return [Numeric, nil] the header's seconds from an {HTTPError}; otherwise nil
        def retry_after(error) = error.is_a?(HTTPError) ? error.retry_after : nil

        private

        # Built on first use and reused.
        #
        # @return [Client]
        def client = @client ||= Client.new
      end
    end
  end
end
