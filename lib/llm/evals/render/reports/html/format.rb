# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # How the report's page prints numbers. Not {CLI::Formatting}: a page shows
          # a missing value as an em dash, and rounds a cost up to the cent.
          module Format
            private

            # @param value [Numeric, nil]
            # @return [String]
            def percent(value) = value.nil? ? "—" : format("%.1f%%", value * 100)

            # @param value [Numeric]
            # @return [String]
            def money(value)
              cents = (value.to_s.to_r * 100).ceil
              format("$%<dollars>d.%<cents>02d", dollars: cents / 100, cents: cents % 100)
            end

            # @param value [Numeric]
            # @return [String]
            def tokens(value) = value.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          end
        end
      end
    end
  end
end
