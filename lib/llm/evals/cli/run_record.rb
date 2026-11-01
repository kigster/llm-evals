# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # What a saved report says about its run: the parsed flags, which preserve
      # the invocation, and the settings that actually reached the experiments,
      # which record the defaults and expanded selections that were implicit.
      RunRecord = Data.define(:command, :cli, :config, :planner, :trackers, :providers, :contenders, :datasets, :runs, :seconds) do
        # @return [Hash]
        def to_h
          { command:, cli:, effective: effective }
        end

        private

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

        def contender(entry)
          settings = entry.settings
          { model: entry.model, provider: providers.for(entry).name, effort: settings[:effort],
            temperature: settings[:temperature], max_tokens: settings[:max_tokens] }
        end
      end
    end
  end
end
