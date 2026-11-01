# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Where a run's results go: the local JSON log, always, then one remote
      # tracker if any, chosen once per run.
      class TrackerResolver
        # @param configuration [Configuration]
        # @param config [Config]
        # @param options [Hash] the parsed flags
        # @param err [IO] says which tracker was chosen, under --verbose
        # @param env [#[]]
        def initialize(configuration:, config:, options:, err:, env: ENV)
          @configuration = configuration
          @config = config
          @options = options
          @err = err
          @env = env
        end

        # --tracker, then tracker: in the config, then the environment. --local is none.
        #
        # @return [Class<Tracker>, nil]
        def remote
          return @remote if defined?(@remote)

          chosen = @configuration.trackers.choose(flag: @options[:tracker], config: @config.tracker, env: @env, local: @options[:local])
          @err.puts "tracker: #{chosen ? "#{chosen.first.tracker_name}, because #{chosen.last}" : "none"}" if @options[:verbose]
          @remote = chosen&.first
        end

        # @return [String]
        def project = @options[:project] || @config.project || @configuration.project || @configuration.name

        # Each experiment gets instances of its own.
        #
        # @return [Array<Tracker>]
        def for_experiment
          context = { suite: @configuration.name, project:, project_id: @options[:project] ? nil : Trackers::Braintrust.project_id(@env) }
          local = Trackers::Local.new(dir: File.join(Dry::CLI::UI::Invocation.root(Dir.pwd), "log", "llm-evals"), **context)
          klass = remote
          [local, klass&.new(**context, options: @config.tracker_options(klass.tracker_name))].compact
        end
      end
    end
  end
end
