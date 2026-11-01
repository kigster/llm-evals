# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # What a saved report says about its run: the parsed flags, which preserve
      # the invocation, and the settings that actually reached the experiments,
      # which record the defaults and expanded selections that were implicit.
      #
      # @!attribute [r] command
      #   @return [String] the action that ran, `run` or `compare`
      # @!attribute [r] cli
      #   @return [Hash{Symbol => Object}] the parsed flags
      # @!attribute [r] config
      #   @return [Config]
      # @!attribute [r] planner
      #   @return [RunPlanner]
      # @!attribute [r] trackers
      #   @return [TrackerResolver]
      # @!attribute [r] providers
      #   @return [Providers::Registry]
      # @!attribute [r] contenders
      #   @return [Array<Models::Contender>]
      # @!attribute [r] datasets
      #   @return [Array<String>]
      # @!attribute [r] runs
      #   @return [Array<Actions::Experiment>]
      # @!attribute [r] seconds
      #   @return [Float] how long the experiments took, by the wall clock
      RunRecord = Data.define(:command, :cli, :config, :planner, :trackers, :providers, :contenders, :datasets, :runs, :seconds) do
        # Replaces `Data#to_h`, so the collaborators stay out of what gets saved.
        #
        # @return [Hash]
        def to_h
          { command:, cli:, effective: effective }
        end

        private

        # What reached the experiments once every default and selection was expanded.
        #
        # @return [Hash{Symbol => Object}]
        def effective
          { project:       trackers.project,
            request_types: config.request_types.map(&:to_s),
            datasets:,
            cases:         runs.group_by(&:dataset).transform_values { |group| group.flat_map { it.cases.map(&:id) }.uniq },
            contenders:    contenders.map { contender(it) },
            defaults:      config.defaults,
            parallelism:   planner.parallelism,
            concurrency:   planner.concurrency,
            tracker:       cli[:local] ? "none" : trackers.remote&.tracker_name,
            seconds: }
        end

        # Names the provider too, which a model id alone does not settle.
        #
        # @param entry [Models::Contender]
        # @return [Hash{Symbol => Object}]
        def contender(entry)
          settings = entry.settings
          { model: entry.model, provider: providers.for(entry).name, effort: settings[:effort],
            temperature: settings[:temperature], max_tokens: settings[:max_tokens] }
        end
      end
    end
  end
end
