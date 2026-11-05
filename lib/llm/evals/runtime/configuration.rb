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

        attr_writer :scorer
        attr_reader :name,
          :root,
          :env_files,
          :cases_glob,
          :hooks,
          :providers,
          :trackers,
          :description,
          :config_path,
          :started_in

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

        # @!attribute [r] config_path
        #   The lineup file as set, which {#config} resolves against the root.
        #   @return [String]

        # @!attribute [r] started_in
        #   The directory the command was typed in, which the search may have left.
        #   @return [String]

        # Starts under the default name at the working directory, with no adapter or scorer.
        def initialize
          @name        = DEFAULT_NAME
          @root        = Dir.pwd
          @env_files   = []
          @cases_glob  = DEFAULT_GLOB
          @config_path = DEFAULT_CONFIG
          @hooks       = []
          @providers   = Providers::Registry.default
          @trackers    = Trackers::Registry.default
          @description = "Run a suite of cases against one or more models and score the replies."
          @project     = nil
          @started_in  = Dir.pwd
          @search      = false
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
          @name        = name
          @root        = File.expand_path(root)
          @env_files   = env_files.map { File.expand_path(it, @root) }
          @description = description if description
        end

        # @param path [String, nil] setting, relative to root; reading when nil
        # @return [String] the absolute path of the lineup file, `.llm-evals.config.yml` at the root by default
        def config(path = nil)
          @config_path = path unless path.nil?
          File.expand_path(@config_path, root)
        end

        # How many directories below the working directory the search goes.
        MAX_SEARCH_DEPTH = 4

        # Directories that hold other people's files or generated ones, never a suite.
        SEARCH_SKIPS = %w[node_modules vendor tmp log pkg coverage].freeze

        # The nearest `.llm-evals.config.yml` below a directory: the shallowest,
        # then the first by name, so that the same tree always gives the same file.
        # Hidden directories and {SEARCH_SKIPS} are not entered.
        #
        # @param from [String] the directory to search below
        # @param max_depth [Integer] how many directories down to look
        # @return [String, nil] the file's path, or nil when there is none
        def self.search_config_file(from: Dir.pwd, max_depth: MAX_SEARCH_DEPTH)
          level = [from]
          max_depth.times do
            level = level.flat_map { search_subdirectories(it) }
            found = level.map { File.join(it, DEFAULT_CONFIG) }.find { File.file?(it) }
            return found if found
          end
          nil
        end

        # @param dir [String]
        # @return [Array<String>] the directories to enter, by name; none when unreadable
        def self.search_subdirectories(dir)
          Dir.children(dir).sort
             .reject { it.start_with?(".") || SEARCH_SKIPS.include?(it) }
             .map { File.join(dir, it) }
             .select { File.directory?(it) && !File.symlink?(it) }
        rescue SystemCallError
          []
        end
        private_class_method :search_subdirectories

        # Records where the command started, since the launcher may change directory to run it.
        #
        # @param dir [String] the directory the command was typed in
        # @param search [Boolean] whether a search was allowed to run
        # @return [void]
        def located_from(dir, search:)
          @started_in = dir
          @search = search
        end

        # @return [Boolean] whether the lineup file exists
        def config_found? = File.file?(config)

        # @return [String] the lineup file's path, relative to where the command was typed
        def relative_config = Pathname(config).relative_path_from(started_in).to_s

        # @return [String] what to say when there is no lineup file
        def config_missing_message
          message = "Configuration file #{DEFAULT_CONFIG} was not found"
          @search ? "#{message}, and the search #{MAX_SEARCH_DEPTH} directories down failed too" : message
        end

        # Where the cases are: a glob relative to root ending in the input file.
        # Each match is a case; the expected answer is `expected.json` beside it.
        #
        # @param glob [String]
        # @return [void]
        def cases(glob)
          @cases_glob = glob
        end

        # Registers the adapter, or reads it. Register the class when
        # {Actions::Adapter#prepare} keeps what it loads: each experiment then
        # gets an adapter of its own, so experiments running at once never
        # see each other's dataset. An instance is shared by every experiment.
        #
        # @param object [Actions::Adapter, Class<Actions::Adapter>, nil] setting; reading when nil
        # @return [Actions::Adapter, nil] nil until one is registered; one of the class's, when a class is
        def adapter(object = nil)
          self.adapter = object unless object.nil?
          @adapter ||= @adapter_class&.new
        end

        # Registers the adapter, as {#adapter} does with an argument.
        #
        # @param value [Actions::Adapter, Class<Actions::Adapter>, nil] nil unregisters it
        # @return [void]
        def adapter=(value)
          @adapter_class, @adapter = value.is_a?(Class) ? [value, nil] : [nil, value]
        end

        # What one experiment runs its cases with.
        #
        # @return [Actions::Adapter, nil] a new one when a class is registered; the registered instance otherwise
        def adapter_for_experiment = @adapter_class ? @adapter_class.new : adapter

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
          self.adapter = instantiate("adapter", file.adapter_name)&.class if adapter.nil?
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
