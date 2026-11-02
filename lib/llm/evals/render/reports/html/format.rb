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

            # Scales a share of 1 to 100%, and shows a missing value as an em dash.
            #
            # @param value [Numeric, nil]
            # @return [String]
            def percent(value) = value.nil? ? "—" : format("%.1f%%", value * 100)

            # Goes through Rational and rounds up, so float noise cannot change a cost and a cost is never understated.
            #
            # @param value [Numeric]
            # @return [String]
            def money(value)
              cents = (value.to_s.to_r * 100).ceil
              format("$%<dollars>d.%<cents>02d", dollars: cents / 100, cents: cents % 100)
            end

            # Groups the digits with commas; fractions are dropped.
            #
            # @param value [Numeric]
            # @return [String]
            def tokens(value) = value.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          end
        end
      end
    end
  end
end
