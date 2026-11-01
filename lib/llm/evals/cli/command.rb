# frozen_string_literal: true

require "io/console"
require "pastel"
require "pathname"

module LLM
  module Evals
    module CLI
      # What every command inherits: the ui helpers, and the flags they all share.
      class Command < Dry::CLI::Command
        include Dry::CLI::UI

        # The width assumed when the output is not a terminal.
        DEFAULT_WIDTH = 120

        def self.inherited(subclass)
          super
          subclass.option :verbose, type: :boolean, default: false, aliases: ["-v"], desc: "Print the full backtrace on failure"
        end

        private

        # @return [Runtime::Configuration] the suite, which must be loaded
        def configuration = LLM::Evals.configuration.require_suite!

        # @return [Datasets::Discovery]
        def discovery = configuration.discovery

        # @see Table#render
        # @return [void]
        def table(rows, **)
          out.puts Table.new(pastel:, width: terminal_width).render(rows, **) unless rows.empty?
        end

        # @see StatusBox#render
        # @param stream [IO] out by default; warnings and errors go to err
        # @return [void]
        def status_box(level, text, stream: out)
          stream.puts StatusBox.new(width: terminal_width, color: color?(stream)).render(level, text)
        end

        # A report written with -o is in color, as dry-cli-ui writes its own.
        #
        # @param stream [IO]
        # @return [Boolean] whether the stream takes color
        def color?(stream = out)
          (stream.respond_to?(:color?) && stream.color?) || (stream.respond_to?(:tty?) && stream.tty? && !ENV.key?("NO_COLOR"))
        end

        def pastel = @pastel ||= Pastel.new(enabled: color?)

        # @return [Integer] columns available on this terminal; {DEFAULT_WIDTH} when it is not one.
        #   While writing to a report, the screen's.
        def terminal_width
          screen = @screen || out
          width = screen.respond_to?(:winsize) && screen.tty? ? screen.winsize[1] : 0
          width.positive? ? width : DEFAULT_WIDTH
        rescue SystemCallError
          DEFAULT_WIDTH
        end

        # @return [Dry::CLI::UI::Invocation] how the command was run, which names its files
        def invocation = @invocation ||= Dry::CLI::UI::Invocation.for(self)

        def relative(path) = Pathname(path).relative_path_from(Dir.pwd).to_s
      end
    end
  end
end
