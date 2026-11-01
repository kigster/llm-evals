# frozen_string_literal: true

require "tty-box"

module LLM
  module Evals
    module CLI
      # ui.info, ui.success, ui.warn and ui.error, painted on their color across
      # the full width of the terminal. dry-cli-ui colors only a box's title, so
      # this draws the box with tty-box, which it uses too. Without color it is a
      # plain framed box.
      class StatusBox
        # Each level's title and colors.
        LEVELS = {
          info:    { title: " Info ", fg: :bright_white, bg: :blue },
          success: { title: " Success ", fg: :black, bg: :green },
          warning: { title: " Warning ", fg: :black, bg: :yellow },
          error:   { title: " Error ", fg: :bright_white, bg: :red }
        }.freeze

        # Told its width and color, rather than asking the terminal itself.
        #
        # @param width [Integer] the box's whole width
        # @param color [Boolean]
        def initialize(width:, color:)
          @width = width
          @color = color
        end

        # Cuts words too wide for the box, before tty-box can drop them.
        #
        # @param level [Symbol] a key of {LEVELS}
        # @param text [String]
        # @return [String]
        # @raise [KeyError] on an unknown level
        def render(level, text)
          look = LEVELS.fetch(level)
          style = @color ? { fg: look[:fg], bg: look[:bg], border: { fg: look[:fg], bg: look[:bg] } } : {}
          # tty-box drops a word wider than the box, such as a long path; cut it first
          TTY::Box.frame(Text.wrap(text, @width - 4),
            width:        @width,
            padding:      [0, 1],
            title:        { top_left: look[:title] },
            style:        style,
            enable_color: @color)
        end
      end
    end
  end
end
