# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # One dataset's section of the page: one entry per experiment, and its cases.
          class DatasetSection
            # Does nothing until {#to_h}.
            #
            # @param name [String]
            # @param summaries [Array<Actions::Experiment::Summary>] the dataset's
            # @param ranking [Ranking]
            def initialize(name, summaries, ranking)
              @name = name
              @summaries = summaries
              @ranking = ranking
            end

            # Ranks only the experiments that covered every case of this dataset.
            #
            # @return [Hash{Symbol => Object}] data for the section
            def to_h
              case_keys = results.map { it.case.key }.uniq
              entries = @summaries.map { @ranking.entry([it], case_keys) }
              complete = entries.select { it[:complete] }
              @ranking.rank(complete)
              { name: @name, summaries: @summaries, case_keys:,
                winner: complete.max_by { it[:ranking] || -1 },
                entries: entries.sort_by { it[:ranking] || -1 }.reverse,
                cases: first_run_of_each_case }
            end

            private

            # @return [Array<Results::RunResult>] every experiment's runs in this dataset
            def results = @summaries.flat_map(&:results)

            # Each case appears once on the page, so its input and expected answer come from its first run.
            #
            # @return [Array<Results::RunResult>] ordered by variant, number and id
            def first_run_of_each_case
              results.group_by { it.case.key }.values.map(&:first).sort_by { [it.case.variant, it.case.number || 0, it.case.id] }
            end
          end
        end
      end
    end
  end
end
