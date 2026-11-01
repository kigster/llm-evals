# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Text fitted to a width, for tables and boxes alike.
      module Text
        module_function

        # Word-wraps text to a width, keeping its own line breaks. A word
        # longer than the width is cut.
        #
        # @param text [String]
        # @param width [Integer]
        # @return [String]
        def wrap(text, width)
          text.split("\n").flat_map { |line| line.scan(/\S.{0,#{width - 1}}(?=\s|\z)|\S{#{width}}/).map(&:strip) }.join("\n")
        end
      end
    end
  end
end
