# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Lists a command's flags by the `group:` each declares, since dry-cli-help
      # prints them in one list. A command with no groups keeps the plain OPTIONS.
      module OptionGroups
        # Each group's heading, in the order they print.
        HEADINGS = { general: "General Options", tui: "TUI Options", browser: "Browser Report Options" }.freeze

        private

        # Overrides `Dry::CLI::Help::Screens::Command#render_options`, which prints one
        # list. The help row goes last among the general options.
        #
        # @return [Array<String>] the section's lines
        def render_options
          shown = command.options.reject { it.options.fetch(:hidden, false) && !include_hidden? }
          return super if shown.none? { it.options[:group] }

          groups = shown.zip(option_rows).group_by { |option, _row| option.options.fetch(:group, :general) }
          HEADINGS.flat_map do |group, heading|
            rows = groups.fetch(group, []).map(&:last)
            rows << self.class::HELP if group == :general
            [format.title(heading), *definitions(rows), ""]
          end[0...-1]
        end
      end
    end
  end
end
