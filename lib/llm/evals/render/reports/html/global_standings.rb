# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # The page's overall ranking: one entry per model at one setting, over
          # every dataset. Only complete contenders are ranked.
          class GlobalStandings
            # Does nothing until {#to_h}.
            #
            # @param summaries [Array<Actions::Experiment::Summary>]
            # @param ranking [Ranking]
            def initialize(summaries, ranking)
              @summaries = summaries
              @ranking = ranking
            end

            # Coverage is judged against every case key seen in the report, across all datasets.
            #
            # @return [Hash{Symbol => Object}] report entries and ranking after coverage checks
            def to_h
              expected_keys = @summaries.flat_map(&:results).map { it.case.key }.uniq
              entries = groups.map { @ranking.entry(it, expected_keys) }
              complete = entries.select { it[:complete] }
              @ranking.rank(complete)
              ranked = complete.sort_by { it[:ranking] || -1 }
              { entries:, expected_count: expected_keys.length, ranked:, leader: ranked.last, best_coverage: entries.max_by { it[:successful] } }
            end

            private

            # @return [Array<Array<Actions::Experiment::Summary>>] one group per model at one setting
            def groups = @summaries.group_by { [it.model.key, it.model.effort, it.model.temperature] }.values
          end
        end
      end
    end
  end
end
