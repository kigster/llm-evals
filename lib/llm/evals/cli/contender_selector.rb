# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Who runs: the models named on the command line, or every model the lineup
      # lists, less those whose provider cannot produce what the suite declares.
      class ContenderSelector
        # @param config [Config]
        # @param providers [Providers::Registry]
        # @param warnings [Warnings] records each refusal
        def initialize(config:, providers:, warnings:)
          @config = config
          @providers = providers
          @warnings = warnings
        end

        # @param models [Array<String>] as given to -m, possibly comma-separated
        # @param options [Hash] the parsed flags, whose settings override the lineup's
        # @return [Array<Contender>]
        # @raise [Error] when nothing names a model, or none is admitted
        def call(models, options)
          named = models.flat_map { it.split(",") }
          settings = overrides(options)
          found = named.empty? ? @config.contenders(settings) : @config.contenders_for(named, settings)
          raise Error, "no models: list some under a provider in #{@config.path}, or pass -m" if found.empty?

          admit(found)
        end

        private

        # @return [Hash{String => Object}] the setting flags that were given
        def overrides(options)
          { "effort" => options[:effort], "temperature" => options[:temperature], "max_tokens" => options[:max_tokens] }
        end

        # A refused model is reported rather than run, failed and billed.
        def admit(found)
          found.each { @providers.for(it) } # an unserved id fails here, before anything is spent
          admitted, refusals = @providers.admit(found, request_types: @config.request_types)
          refusals.each { @warnings.record(it.to_s) }
          raise Error, "no admitted models: #{refusals.join("; ")}" if admitted.empty?

          admitted
        end
      end
    end
  end
end
