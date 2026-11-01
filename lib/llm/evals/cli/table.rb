# frozen_string_literal: true

require "tty-table"

module LLM
  module Evals
    module CLI
      # ui.table, as wide as the terminal (and so as the status boxes), with every
      # all-numeric column right-aligned and a line between rows once any cell
      # spans several. dry-cli-ui does none of that, so this renders through
      # tty-table, as it does.
      #
      # The fill column takes whatever width the others leave. With wrap, its text
      # is word-wrapped to fit; without, it is only ever widened, so an id is never
      # broken and a table too wide for the screen stays so.
      class Table
        # A cell that reads as a number: 42, 1,200, 97.1%, 3.5s, $0.0042.
        NUMBER = /\A-?\$?\d[\d,]*(?:\.\d+)?[%s]?\z/

        # Cells that stand in for a number without being one; they do not stop
        # a column from right-aligning.
        PLACEHOLDERS = ["", "-", "default"].freeze

        # The narrowest a wrapped column gets, however full the screen.
        MIN_WRAP = 30

        # Holds no rows, so one instance can draw any number of tables.
        #
        # @param pastel [Pastel]
        # @param width [Integer] the columns available
        def initialize(pastel:, width:)
          @pastel = pastel
          @width = width
        end

        # Draws one table, with widths measured before any highlight is painted on.
        #
        # @param rows [Array<Array<#to_s>>]
        # @param header [Array<String>]
        # @param highlight [Array<Integer>] rows drawn in bold yellow (when color is on)
        # @param fill [Integer] the column that absorbs the spare width
        # @param wrap [Boolean] word-wrap the fill column to fit
        # @return [String]
        def render(rows, header:, highlight: [], fill: 1, wrap: false)
          cells = rows.map { |row| row.map(&:to_s) }
          widths = fitted_widths(header, cells, fill, wrap)
          alignments = alignments(header, cells)
          multiline = cells.flatten.any? { it.include?("\n") }
          cells = cells.each_with_index.map { |row, index| highlight.include?(index) ? row.map { @pastel.bold.yellow(it) } : row }
          TTY::Table.new(header: header.map { @pastel.bold(it) }, rows: cells).render(
            :unicode,
            padding:       [0, 1],
            width:         Dry::CLI::UI::Widgets::Table::UNLIMITED,
            alignments:    alignments,
            multiline:     multiline,
            column_widths: widths
          ) { |renderer| renderer.border.separator = :each_row if multiline }
        end

        private

        # Wraps the fill column's cells in place when asked to.
        #
        # @param header [Array<String>]
        # @param cells [Array<Array<String>>] modified when wrapping
        # @param fill [Integer] the column that absorbs the spare width
        # @param wrap [Boolean] word-wrap the fill column to fit
        # @return [Array<Integer>] each column's width
        def fitted_widths(header, cells, fill, wrap)
          widths = column_widths([header] + cells)
          spare = @width - (widths.sum - widths[fill]) - ((3 * widths.size) + 1)
          if wrap
            widths[fill] = [spare, MIN_WRAP].max
            cells.each { it[fill] = Text.wrap(it[fill], widths[fill]) }
          else
            widths[fill] = [spare, widths[fill]].max
          end
          widths
        end

        # A column right-aligns when all it holds reads as a number. One holding only placeholders stays left.
        #
        # @param header [Array<String>]
        # @param cells [Array<Array<String>>]
        # @return [Array<Symbol>] `:left` or `:right`, one per column
        def alignments(header, cells)
          header.each_index.map do |index|
            column = cells.map { it[index] }.reject { PLACEHOLDERS.include?(it) }
            !column.empty? && column.all? { NUMBER.match?(it) } ? :right : :left
          end
        end

        # Measures past any color, which takes up no columns.
        #
        # @param rows [Array<Array<#to_s>>]
        # @return [Array<Integer>] each column's widest line
        def column_widths(rows)
          rows.transpose.map { |column| column.flat_map { @pastel.strip(it.to_s).split("\n") }.map(&:length).max.to_i }
        end
      end
    end
  end
end
