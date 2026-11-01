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
    #     display: both             # none, tui, browser or both (default)
    #   errors:                      # optional: when to give up; see {Actions::ErrorBudget}
    #     abort_after:
    #       total: 1000
    #       percent: 60
    #   weighted_score:              # optional: what matters most; see {Scoring::WeightedScore}
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
    # A call waits on every `rate_limit` that matches it; see {Models::Throttle}.
    class Config
      # The request types a suite may declare. `prompt` is a chat completion:
      # system and user text in, text out. `typesafe` is TypeSafe's typed
      # question API, whose request shape the first such suite will define.
      REQUEST_TYPES = %w[prompt typesafe].freeze

      BUILTIN = {
        "effort" => "default", "temperature" => 0.2, "max_tokens" => 4096, "parallelism" => 4
      }.freeze

      RESULT_DISPLAYS = %w[none tui browser both].freeze

      # The displays that draw in the terminal, and those that write the HTML report.
      TERMINAL_DISPLAYS = %w[tui both].freeze
      BROWSER_DISPLAYS = %w[browser both].freeze

      # What a lineup that says nothing gets: the terminal summary, and the HTML report opened in the browser.
      DEFAULT_DISPLAY = "both"

      attr_reader :path, :providers

      # Reads every section a run needs before anything is spent, so a bad one
      # fails the run rather than the report at its end.
      #
      # @return [void]
      # @raise [Error] on the first bad section
      def validate!
        results
        error_budget
        score_weights
      end

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

      # @return [Results]
      # @raise [Error] when a setting has the wrong type or an unknown display
      def results = Results.from_hash(@data.fetch("results", {}), path:)

      # @return [Hash{String => Object}] `weighted_score.weights`; see {Scoring::WeightedScore}
      # @raise [Error] when either level is not a mapping
      def score_weights = ScoreWeights.from_hash(@data["weighted_score"], path:)

      # When to give up on a run; see {Actions::ErrorBudget}.
      #
      # @return [Actions::ErrorBudget, nil] nil when the file sets no limit
      # @raise [Error] on a limit that is missing or out of range
      def error_budget
        section = @data["errors"]
        ErrorLimits.from_hash(section, path:).budget unless section.nil?
      end

      # Every vendor/model/effort/temperature combination the file lists, in
      # the file's order.
      #
      # @param overrides [Hash{String => Object}] values from the command line; nil entries are ignored
      # @return [Array<Models::Contender>]
      # @raise [Error] on a section or entry the file format does not have
      def contenders(overrides = {})
        builder = ContenderBuilder.new(defaults:, overrides:)
        listing.entries.flat_map do |entry|
          builder.call(entry.id, entry.settings, provider: entry.provider.direct? ? entry.provider.name.to_sym : nil)
        end
      end

      # The file's `rate_limit`s, ready for calls. The same one every time, since
      # the limits only hold if every model of a run shares them.
      #
      # @return [Models::Throttle]
      # @raise [Error] on a limit that is missing a number, out of range or set twice
      def throttle = @throttle ||= Models::Throttle.new(listing.limits)

      # The models given on the command line, at the file's default settings.
      #
      # @param models [Array<String>] model ids
      # @param overrides [Hash{String => Object}]
      # @return [Array<Models::Contender>]
      def contenders_for(models, overrides = {})
        builder = ContenderBuilder.new(defaults:, overrides:)
        models.flat_map { builder.call(it) }
      end

      private

      def listing = @listing ||= Listing.new(@data, path:, providers:)
    end
  end
end
