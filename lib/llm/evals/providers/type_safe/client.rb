# frozen_string_literal: true

require "json"
require "net/http"

module LLM
  module Evals
    module Providers
      class TypeSafe < Base
        # The HTTP side of typed questions: credentials, transport, and turning
        # whatever came back into a parsed body or a gem error.
        class Client
          URL = URI("https://api.typesafe.ai/v1/systemone")
          OPEN_TIMEOUT = 10
          READ_TIMEOUT = 120

          # @param payload [Hash]
          # @return [Hash] the reply, which has `answers`
          # @raise [Error] on a missing key, or a 2xx that is not a usable answer
          # @raise [HTTPError] on any status but 2xx
          def ask(payload)
            key = ENV.fetch(KEY, "")
            raise Error, "#{KEY} is not set" if key.empty?

            response = post(payload, key)
            raise HTTPError, response unless response.is_a?(Net::HTTPSuccess)

            parsed(response.body, payload[:model])
          end

          private

          def post(payload, key)
            request = Net::HTTP::Post.new(URL, "Authorization" => "Bearer #{key}", "Content-Type" => "application/json")
            request.body = JSON.generate(payload)
            Net::HTTP.start(URL.host, URL.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) { it.request(request) }
          end

          def parsed(text, model)
            body = JSON.parse(text)
            return body if body.is_a?(Hash) && body["answers"].is_a?(Hash)

            raise Error, "#{model}: unexpected TypeSafe answer, no answers: #{text.to_s[0, 500]}"
          rescue JSON::ParserError
            raise Error, "#{model}: unexpected TypeSafe answer, not JSON: #{text.to_s[0, 500]}"
          end
        end
      end
    end
  end
end
