# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # The page's overall ranking: one entry per model at one setting, over
          # every dataset. Only complete contenders are ranked.
          class GlobalStandings
            # @param summaries [Array<Experiment::Summary>]
            # @param scoring [Scoring]
            def initialize(summaries, scoring)
              @summaries = summaries
              @scoring = scoring
            end

            # @return [Hash{Symbol => Object}] report entries and ranking after coverage checks
            def to_h
              expected_keys = @summaries.flat_map(&:results).map { it.case.key }.uniq
              entries = groups.map { @scoring.entry(it, expected_keys) }
              complete = entries.select { it[:complete] }
              @scoring.rank(complete)
              ranked = complete.sort_by { it[:ranking] || -1 }
              { entries:, expected_count: expected_keys.length, ranked:, leader: ranked.last, best_coverage: entries.max_by { it[:successful] } }
            end

            private

            def groups = @summaries.group_by { [it.model.key, it.model.effort, it.model.temperature] }.values
          end
        end
      end
    end
  end
end
