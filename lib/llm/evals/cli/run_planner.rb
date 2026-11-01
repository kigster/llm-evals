# frozen_string_literal: true

require "etc"

module LLM
  module Evals
    module CLI
      # What a run will do: which datasets, how many cases and experiments at
      # once, and one experiment per dataset and contender.
      class RunPlanner
        # @param configuration [Configuration]
        # @param config [Config]
        # @param options [Hash] the parsed flags
        # @param trackers [TrackerResolver]
        def initialize(configuration:, config:, options:, trackers:)
          @configuration = configuration
          @config = config
          @options = options
          @trackers = trackers
        end

        # @param names [Array<String>] as given to -d, possibly comma-separated; empty means every dataset
        # @return [Array<String>]
        # @raise [Error] on an unknown dataset, before anything is spent
        def datasets(names)
          names = names.flat_map { it.split(",") }.uniq
          return every_dataset if names.empty?

          names.each { discovery.cases(dataset: it) }
        end

        # @param datasets [Array<String>]
        # @param contenders [Array<Contender>]
        # @return [Array<Experiment>]
        def experiments(datasets, contenders)
          datasets.flat_map { |dataset| contenders.map { experiment(it, dataset) } }
        end

        # @return [Integer] cases in flight at once, per model
        def parallelism = Integer(@options[:parallelism] || @config.defaults["parallelism"])

        # -j, else one experiment per CPU. Uncapped, a full lineup started
        # every model x dataset pair at once: 140 experiments, each with its
        # own pool of case threads, all fighting for the network and the screen.
        #
        # @return [Integer] experiments at once; 0 means all of them
        # @raise [Error] on a negative or non-numeric -j
        def concurrency
          value = @options[:concurrency] || Etc.nprocessors
          Integer(value).tap { raise Error, "--concurrency must be 0 or more, got #{value}" if it.negative? }
        rescue ArgumentError, TypeError
          raise Error, "--concurrency must be a whole number, got #{value.inspect}"
        end

        private

        def discovery = @configuration.discovery

        def every_dataset
          discovery.datasets.tap { raise Error, "no datasets under #{discovery.root}" if it.empty? }
        end

        def experiment(contender, dataset)
          Experiment.new(
            model:       @configuration.providers.model_for(contender, throttle: @config.throttle),
            cases:       discovery.cases!(dataset:, only: @options[:case]),
            adapter:     @configuration.adapter,
            scorer:      @configuration.scorer,
            parallelism:,
            trackers:    @trackers.for_experiment
          )
        end
      end
    end
  end
end
