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
    #   errors:                      # optional: when to give up; see {ErrorBudget}
    #     abort_after:
    #       total: 1000
    #       percent: 60
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

      # When to give up on a run; see {ErrorBudget}. Both limits must be met, and
      # `percent` needs `total`, since one failed first call is already 100%.
      #
      # @return [ErrorBudget, nil] nil when the file sets no limit
      # @raise [Error] on a limit that is missing or out of range
      def error_budget
        section = @data["errors"]
        return if section.nil?

        limits = section["abort_after"] if section.is_a?(Hash)
        raise Error, "#{path}: errors needs an abort_after: mapping of total and percent" unless limits.is_a?(Hash)

        total = limits["total"]
        percent = limits["percent"]
        raise Error, "#{path}: errors.abort_after.total must be a whole number above 0" unless total.is_a?(Integer) && total.positive?
        unless percent.nil? || (percent.is_a?(Numeric) && percent.positive? && percent <= 100)
          raise Error, "#{path}: errors.abort_after.percent must be above 0 and at most 100"
        end

        ErrorBudget.new(total:, percent:)
      end

      # Every vendor/model/effort/temperature combination the file lists, in
      # the file's order.
      #
      # @param overrides [Hash{String => Object}] values from the command line; nil entries are ignored
      # @return [Array<Contender>]
      # @raise [Error] on a section or entry the file format does not have
      def contenders(overrides = {})
        listing.entries.flat_map do |entry|
          expand(entry.id, entry.settings, overrides, provider: entry.provider.direct? ? entry.provider.name.to_sym : nil)
        end
      end

      # The file's `rate_limit`s, ready for calls. The same one every time, since
      # the limits only hold if every model of a run shares them.
      #
      # @return [Throttle]
      # @raise [Error] on a limit that is missing a number, out of range or set twice
      def throttle = @throttle ||= Throttle.new(listing.limits)

      # The models given on the command line, at the file's default settings.
      #
      # @param models [Array<String>] model ids
      # @param overrides [Hash{String => Object}]
      # @return [Array<Contender>]
      def contenders_for(models, overrides = {})
        models.flat_map { expand(it, {}, overrides) }
      end

      private

      def listing = @listing ||= Listing.new(@data, path:, providers:)

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
