# frozen_string_literal: true

require "yaml"

module LLM
  module Evals
    # The suite's `.llm-evals.config.yml`: which models to compare, at which
    # settings, and which kinds of request the suite can produce.
    #
    #   project: my-evals            # Braintrust project name
    #   request_types: [prompt]      # required: what the adapter sends; a provider must match
    #   tracker: braintrust          # optional: the one remote tracker; else the environment decides
    #   logfire:                     # optional: a tracker's own settings
    #     include_replies: true
    #   require: my_gem/evals        # optional: a path (or list) to require, for a suite with no eval_helper.rb
    #   adapter: MyGem::Evals::Adapter   # optional: constant names, instantiated with no arguments
    #   scorer: MyGem::Evals::Scorer
    #   defaults:
    #     effort: default
    #     temperature: 0.2
    #     max_tokens: 4096
    #     parallelism: 4
    #   results:
    #     autosave: true           # completed runs are saved as JSON (default)
    #     destination: ./evals/results/
    #     temp_dir: ./tmp           # temporary JSON used when autosave is off
    #     display: browser          # none, tui or browser
    #   weighted_score:              # optional: what matters most; see {WeightedScore}
    #     weights:
    #       score: 0.6
    #       cost: -0.4
    #   openrouter:                  # a provider's name; this one needs OPENROUTER_API_KEY
    #     rate_limit: { burst: 1000, per_minute: 500 }
    #     vendors:
    #       anthropic:
    #         rate_limit: { burst: 10, per_minute: 50 }
    #         models:
    #           - model: claude-haiku-5.5
    #             rate_limit: { burst: 5, per_minute: 20 }
    #             effort: [default, low]  # a list expands into one contender per value
    #   typesafe:                    # a provider with no vendors; this one needs TYPESAFE_API_KEY
    #     models:
    #       - jev-1.14.0             # a bare name is the same as `- model: jev-1.14.0`
    #
    # An entry under `vendors:` becomes "<vendor>/<model>", the id a provider
    # recognises; one under `models:` becomes the provider's prefix and the name.
    # A call waits on every `rate_limit` that matches it; see {Throttle}.
    class Config
      # The request types a suite may declare. `prompt` is a chat completion:
      # system and user text in, text out. `typesafe` is TypeSafe's typed
      # question API, whose request shape the first such suite will define.
      REQUEST_TYPES = %w[prompt typesafe].freeze

      SECTION_KEYS = %w[rate_limit vendors models].freeze
      VENDOR_KEYS = %w[rate_limit models].freeze
      ENTRY_KEYS = %w[model effort temperature max_tokens rate_limit].freeze

      BUILTIN = {
        "effort" => "default", "temperature" => 0.2, "max_tokens" => 4096, "parallelism" => 4
      }.freeze

      Results = Data.define(:autosave, :destination, :temp_dir, :display_mode)
      RESULT_DISPLAYS = %w[none tui browser].freeze

      attr_reader :path, :providers

      # @param path [String] read when it exists; an absent file is an empty lineup
      # @param providers [Providers::Registry] whose names the file's sections may use
      def initialize(path, providers: Providers::Registry.default)
        @path = path
        @providers = providers
        @data = File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
      end

      # @return [String, nil] the Braintrust project name
      def project = @data["project"]

      # The remote tracker the file chooses; a list of more than one is an
      # error, since exactly one remote tracker runs, or none.
      #
      # @return [String, nil]
      # @raise [Error] on a list of several
      def tracker
        listed = Array(@data["tracker"]).map(&:to_s)
        raise Error, "#{path}: tracker: names #{listed.join(", ")}; exactly one remote tracker runs, or none" if listed.size > 1

        listed.first
      end

      # A tracker's own section of the file, e.g. `logfire: { include_replies: true }`.
      #
      # @param name [String]
      # @return [Hash]
      def tracker_options(name) = (@data[name.to_s].is_a?(Hash) ? @data[name.to_s] : {}).transform_keys(&:to_s)

      # @return [Array<String>] the `require:` key, one path or a list
      def requires = Array(@data["require"]).map(&:to_s)

      # @return [String, nil] the `adapter:` constant name
      def adapter_name = @data["adapter"]&.to_s

      # @return [String, nil] the `scorer:` constant name
      def scorer_name = @data["scorer"]&.to_s

      # The kinds of request the suite's adapter produces. A provider whose
      # request type is not listed cannot serve this suite, whatever model it
      # names, so the list is required: without it every contender would be
      # admitted on faith and fail at the first call.
      #
      # @return [Array<Symbol>]
      # @raise [Error] when the key is missing, empty, or names an unknown type
      def request_types
        listed = Array(@data["request_types"]).map(&:to_s)
        raise Error, "#{path}: request_types is required; list one or more of #{REQUEST_TYPES.join(", ")}" if listed.empty?

        unknown = listed - REQUEST_TYPES
        raise Error, "#{path}: unknown request_types #{unknown.join(", ")}; known: #{REQUEST_TYPES.join(", ")}" if unknown.any?

        listed.map(&:to_sym)
      end

      # @return [Hash{String => Object}] the built-in defaults under the file's own
      def defaults = BUILTIN.merge(@data.fetch("defaults", nil) || {})

      # Where completed runs are saved and how they are presented. Paths are
      # rooted at the caller's working directory so the same config works from
      # a project root or when invoked by a task runner.
      #
      # @return [Results]
      # @raise [Error] when a setting has the wrong type or an unknown display
      def results
        section = @data.fetch("results", {})
        raise Error, "#{path}: results must be a mapping" unless section.is_a?(Hash)

        autosave = section.fetch("autosave", true)
        unless [true, false].include?(autosave)
          raise Error, "#{path}: results.autosave must be true or false"
        end

        display = section.fetch("display", "tui").to_s
        unless RESULT_DISPLAYS.include?(display)
          raise Error, "#{path}: results.display must be one of #{RESULT_DISPLAYS.join(", ")}"
        end

        destination = section.fetch("destination", "./evals/results").to_s
        temp_dir = section.fetch("temp_dir", "./tmp").to_s
        Results.new(autosave:,
          destination: File.expand_path(destination, Dir.pwd),
          temp_dir: File.expand_path(temp_dir, Dir.pwd),
          display_mode: display)
      end

      # @return [Hash{String => Object}] `weighted_score.weights`; see {WeightedScore}
      # @raise [Error] when either level is not a mapping
      def score_weights
        section = @data["weighted_score"]
        return {} if section.nil?

        weights = section["weights"] if section.is_a?(Hash)
        raise Error, "#{path}: weighted_score needs a weights: mapping of column to number" unless weights.is_a?(Hash)

        weights.transform_keys(&:to_s)
      end

      # Every vendor/model/effort/temperature combination the file lists, in
      # the file's order.
      #
      # @param overrides [Hash{String => Object}] values from the command line; nil entries are ignored
      # @return [Array<Contender>]
      # @raise [Error] on a section or entry the file format does not have
      def contenders(overrides = {})
        sections.flat_map do |provider, section|
          listed(provider, section).flat_map do |_scope, id, entry|
            expand(id, entry, overrides, provider: provider.direct? ? provider.name.to_sym : nil)
          end
        end
      end

      # The file's `rate_limit`s, ready for calls.
      #
      # @return [Throttle]
      # @raise [Error] on a limit that is missing a number or out of range
      def throttle
        limits = {}
        sections.each do |provider, section|
          limit(limits, provider.name, section)
          vendors_of(section).each { |vendor, listing| limit(limits, "#{provider.name}/#{vendor}", listing) }
          listed(provider, section).each { |scope, _id, entry| limit(limits, scope, entry) }
        end
        Throttle.new(limits)
      end

      # The models given on the command line, at the file's default settings.
      #
      # @param models [Array<String>] model ids
      # @param overrides [Hash{String => Object}]
      # @return [Array<Contender>]
      def contenders_for(models, overrides = {})
        models.flat_map { expand(it, {}, overrides) }
      end

      private

      # @return [Array<Array(Providers::Base, Hash)>] the file's provider sections
      # @raise [Error] on the old top-level keys, or a section naming no provider
      def sections
        retired = %w[vendors direct] & @data.keys
        raise Error, "#{path}: #{retired.join(" and ")} no longer exist; list models under a provider, as `openrouter: { vendors: ... }` or `typesafe: { models: ... }`" if retired.any?

        names = providers.map(&:name)
        @data.filter_map do |name, section|
          next unless section.is_a?(Hash) && section.keys.intersect?(%w[vendors models])
          raise Error, "#{path}: unknown provider #{name.inspect}; known: #{names.join(", ")}" unless names.include?(name.to_s)

          known!(name, section, SECTION_KEYS)
          [providers.find { it.name == name.to_s }, section]
        end
      end

      def vendors_of(section)
        vendors = section["vendors"] || {}
        raise Error, "#{path}: vendors must be a mapping of vendor to models" unless vendors.is_a?(Hash)

        vendors.each do |vendor, listing|
          raise Error, "#{path}: vendor #{vendor} needs a models: list" unless listing.is_a?(Hash)

          known!(vendor, listing, VENDOR_KEYS)
        end
      end

      # @return [Array<Array(String, String, Hash)>] each entry's throttle scope, model id and settings
      def listed(provider, section)
        grouped = vendors_of(section).flat_map do |vendor, listing|
          entries(vendor, listing).map { ["#{provider.name}/#{vendor}/#{it["model"]}", "#{provider.prefix}#{vendor}/#{it["model"]}", it] }
        end
        grouped + entries(provider.name, section).map { ["#{provider.name}/#{it["model"]}", "#{provider.prefix}#{it["model"]}", it] }
      end

      def entries(owner, listing)
        Array(listing["models"]).map do |entry|
          entry = { "model" => entry } if entry.is_a?(String)
          raise Error, "#{path}: every entry under #{owner} needs a model" unless entry.is_a?(Hash) && entry["model"]

          known!(entry["model"], entry, ENTRY_KEYS)
          entry
        end
      end

      def known!(owner, mapping, keys)
        unknown = mapping.keys - keys
        raise Error, "#{path}: unknown keys under #{owner}: #{unknown.join(", ")}; known: #{keys.join(", ")}" if unknown.any?
      end

      def limit(limits, scope, owner)
        given = owner["rate_limit"]
        return if given.nil?

        burst, per_minute = given.values_at("burst", "per_minute") if given.is_a?(Hash)
        unless [burst, per_minute].all? { it.is_a?(Integer) && it.positive? } && given.size == 2
          raise Error, "#{path}: rate_limit of #{scope} needs burst and per_minute, whole numbers above 0"
        end

        limits[scope] = Throttle::Limit.new(burst:, per_minute:)
      end

      def expand(model, entry, overrides, provider: nil)
        settings = defaults.merge(entry).merge(overrides.compact)
        Array(settings["effort"]).product(Array(settings["temperature"])).map do |effort, temperature|
          Contender.new(model: model,
            effort: effort.to_s,
            temperature: temperature,
            max_tokens: Integer(settings["max_tokens"]),
            provider: provider)
        end
      end
    end
  end
end
