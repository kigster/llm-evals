# frozen_string_literal: true

module LLM
  module Evals
    module Runtime
      # Everything a suite tells the gem, through {LLM::Evals.configure}.
      # Paths are relative to `root`, the directory the eval helper lives in.
      class Configuration
        # Where cases are looked for, relative to the root, when a suite does not say.
        DEFAULT_GLOB = "datasets/*/cases/**/input.txt"
        # The suite's name until it calls {#suite}.
        DEFAULT_NAME = "llm-evals"
        # The lineup file's name, also searched for by {Helper.locate}.
        DEFAULT_CONFIG = ".llm-evals.config.yml"

        attr_writer :adapter, :scorer
        attr_reader :name, :root, :env_files, :cases_glob, :hooks, :providers, :trackers, :description

        # @!attribute [w] adapter
        #   Registers the adapter, as {#adapter} does with an argument.
        #   @param value [Actions::Adapter, nil]
        #   @return [Actions::Adapter, nil]

        # @!attribute [w] scorer
        #   Registers the scorer, as {#scorer} does with an argument.
        #   @param value [Scoring::Scorer, nil]
        #   @return [Scoring::Scorer, nil]

        # @!attribute [r] name
        #   Titles the help and tags the experiments.
        #   @return [String]

        # @!attribute [r] root
        #   The absolute directory other paths are relative to; the helper's directory.
        #   @return [String]

        # @!attribute [r] env_files
        #   Absolute paths of the dotenv files to load, whether or not they exist.
        #   @return [Array<String>]

        # @!attribute [r] cases_glob
        #   Finds each case's input file, relative to the root.
        #   @return [String]

        # @!attribute [r] hooks
        #   The {#before_run} blocks, in the order given.
        #   @return [Array<Proc>]

        # @!attribute [r] providers
        #   The defaults, plus any added through {#provider}.
        #   @return [Providers::Registry]

        # @!attribute [r] trackers
        #   The defaults, plus any added through {#tracker}.
        #   @return [Trackers::Registry]

        # @!attribute [r] description
        #   One line for the help's header.
        #   @return [String]

        # Starts under the default name at the working directory, with no adapter or scorer.
        def initialize
          @name = DEFAULT_NAME
          @root = Dir.pwd
          @env_files = []
          @cases_glob = DEFAULT_GLOB
          @config_path = DEFAULT_CONFIG
          @hooks = []
          @providers = Providers::Registry.default
          @trackers = Trackers::Registry.default
          @description = "Run a suite of cases against one or more models and score the replies."
          @project = nil
        end

        # Names the suite. The name titles the help and tags the experiments.
        #
        # @param name [String]
        # @param root [String] where .llm-evals.config.yml and datasets/ live; the helper's directory
        # @param env_files [Array<String>] dotenv files to load, relative to root; the first that exists wins nothing,
        #   all that exist load, and an exported variable beats them all
        # @param description [String, nil] one line for the help's header
        # @return [void]
        def suite(name, root:, env_files: [], description: nil)
          @name = name
          @root = File.expand_path(root)
          @env_files = env_files.map { File.expand_path(it, @root) }
          @description = description if description
        end

        # Where the cases are: a glob relative to root ending in the input file.
        # Each match is a case; the expected answer is `expected.json` beside it.
        #
        # @param glob [String]
        # @return [void]
        def cases(glob)
          @cases_glob = glob
        end

        # @param object [Actions::Adapter, nil] setting; reading when nil
        # @return [Actions::Adapter, nil] nil until one is registered
        def adapter(object = nil)
          @adapter = object unless object.nil?
          @adapter
        end

        # @param object [Scoring::Scorer, nil] setting; reading when nil
        # @return [Scoring::Scorer, nil] nil until one is registered
        def scorer(object = nil)
          @scorer = object unless object.nil?
          @scorer
        end

        # Runs once, after the env files are loaded and before any model is
        # called. The place to reset a library that read ENV at require time.
        #
        # @param block [Proc] the hook
        # @yield once, with no arguments
        # @return [void]
        def before_run(&block)
          @hooks << block
        end

        # Adds a provider, ahead of the defaults, so a suite's own transport
        # wins the ids it claims.
        #
        # @param provider [Providers::Base]
        # @return [void]
        def provider(provider)
          @providers.register(provider)
        end

        # Adds a tracker class, so a run can choose it by name with `--tracker`
        # or `tracker:`, or have its env key select it.
        #
        # @param klass [Class<Trackers::Base>]
        # @return [void]
        def tracker(klass)
          @trackers.register(klass)
        end

        # @param path [String, nil] setting, relative to root; reading when nil
        # @return [String] the absolute path of the lineup file, `.llm-evals.config.yml` at the root by default
        def config(path = nil)
          @config_path = path unless path.nil?
          File.expand_path(@config_path, root)
        end

        # @param name [String, nil] setting; reading when nil
        # @return [String, nil] the Braintrust project, when .llm-evals.config.yml does not name one
        def project(name = nil)
          @project = name unless name.nil?
          @project
        end

        # @return [Datasets::Discovery] the cases, as the glob finds them
        def discovery = Datasets::Discovery.new(root: root, glob: cases_glob)

        # @return [Config] the lineup file
        def lineup = Config.new(config, providers:)

        # @return [Environment]
        def runtime = Environment.new(env_files: env_files, hooks: hooks, app_name: name)

        # @return [Boolean] whether an adapter and a scorer are registered
        def complete? = !adapter.nil? && !scorer.nil?

        # Fails a command that needs the suite when no helper was loaded, with
        # the fix in the message, instead of a NoMethodError on nil.
        #
        # @return [self]
        # @raise [Error]
        def require_suite!
          resolve_from_config!
          return self if complete?

          raise Error,
            "no suite is configured: register an adapter and a scorer in evals/eval_helper.rb, or set " \
            "adapter: and scorer: (with require:) in #{config}; --helper PATH or LLM_EVALS_HELPER names another helper"
        end

        # Fills whatever the helper left unset from the config file's `require:`,
        # `adapter:` and `scorer:` keys, so a suite can be config-only: its Ruby
        # lives in its own gem and `evals/` holds the file and the datasets. The
        # helper, when there is one, was loaded first and wins.
        #
        # @return [void]
        # @raise [Error] naming the key and the value when a require fails or a constant is unknown
        def resolve_from_config!
          return if complete? || !File.exist?(config)

          file = lineup
          file.requires.each do |feature|
            require feature
          rescue LoadError => e
            raise Error, "#{config}: require: #{feature} could not be loaded (#{e.message}); is its gem in the bundle?"
          end
          @adapter ||= instantiate("adapter", file.adapter_name)
          @scorer ||= instantiate("scorer", file.scorer_name) # rubocop:disable Naming/MemoizedInstanceVariableName
        end

        private

        # @param key [String] the config key, for the error
        # @param name [String, nil] the constant's name
        # @return [Object, nil] a new instance of the named constant; nil when no name is set
        # @raise [Error] when the constant is unknown or wants arguments
        def instantiate(key, name)
          return nil if name.nil? || name.empty?

          Object.const_get(name).new
        rescue NameError, ArgumentError => e
          raise Error,
            "#{config}: #{key}: #{name} could not be instantiated (#{e.class}: #{e.message}); " \
            "name a constant the require: key loads, taking no arguments"
        end
      end
    end
  end
end
