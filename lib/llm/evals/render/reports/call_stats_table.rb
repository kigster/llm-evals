# frozen_string_literal: true

module LLM
  module Evals
    module Render
      # The saved snapshot's presentations: JSON, HTML, terminal, and the pipeline joining them.
      module Reports
        # {Stats::CallStats} as the cells of a table, which the caller draws.
        class CallStatsTable
          # The table's column titles, in the order {#rows} fills them.
          HEADER = ["calls by provider, vendor, model", "requests", "errors", "req/s", "avg", "p95"].freeze
          # What a cell shows for a value that is missing.
          EMPTY = "-"

          # Formats only; the numbers stay {Stats::CallStats}'s to work out.
          #
          # @param stats [Stats::CallStats]
          def initialize(stats)
            @stats = stats
          end

          # The name and counts stay as they are; the rate and timings become Strings.
          #
          # @return [Array<Array>] one per {Stats::CallStats::Row}, in {HEADER}'s order
          def rows
            @stats.rows.map do |row|
              [row.name, row.requests, row.errors, rate(row.per_second), seconds(row.latency), seconds(row.p95)]
            end
          end

          private

          # @param value [Float, nil] requests per second
          # @return [String] two decimals, or {EMPTY}
          def rate(value) = value ? format("%.2f", value) : EMPTY

          # @param value [Float, nil] seconds
          # @return [String] two decimals with an "s", or {EMPTY}
          def seconds(value) = value ? format("%.2fs", value) : EMPTY
        end
      end
    end
  end
end
