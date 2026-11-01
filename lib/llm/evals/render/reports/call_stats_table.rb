# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        # {CallStats} as the cells of a table, which the caller draws.
        class CallStatsTable
          HEADER = ["calls by provider, vendor, model", "requests", "errors", "req/s", "avg", "p95"].freeze
          EMPTY = "-"

          # @param stats [CallStats]
          def initialize(stats)
            @stats = stats
          end

          # @return [Array<Array>] one per {CallStats::Row}, in {HEADER}'s order
          def rows
            @stats.rows.map do |row|
              [row.name, row.requests, row.errors, rate(row.per_second), seconds(row.latency), seconds(row.p95)]
            end
          end

          private

          def rate(value) = value ? format("%.2f", value) : EMPTY

          def seconds(value) = value ? format("%.2fs", value) : EMPTY
        end
      end
    end
  end
end
