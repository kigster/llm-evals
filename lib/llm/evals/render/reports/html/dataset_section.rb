# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # One dataset's section of the page: one entry per experiment, and its cases.
          class DatasetSection
            # @param name [String]
            # @param summaries [Array<Experiment::Summary>] the dataset's
            # @param scoring [Scoring]
            def initialize(name, summaries, scoring)
              @name = name
              @summaries = summaries
              @scoring = scoring
            end

            # @return [Hash{Symbol => Object}] data for the section
            def to_h
              case_keys = results.map { it.case.key }.uniq
              entries = @summaries.map { @scoring.entry([it], case_keys) }
              complete = entries.select { it[:complete] }
              @scoring.rank(complete)
              { name: @name, summaries: @summaries, case_keys:,
                winner: complete.max_by { it[:ranking] || -1 },
                entries: entries.sort_by { it[:ranking] || -1 }.reverse,
                cases: first_run_of_each_case }
            end

            private

            def results = @summaries.flat_map(&:results)

            def first_run_of_each_case
              results.group_by { it.case.key }.values.map(&:first).sort_by { [it.case.variant, it.case.number || 0, it.case.id] }
            end
          end
        end
      end
    end
  end
end
