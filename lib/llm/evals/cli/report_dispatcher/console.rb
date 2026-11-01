# frozen_string_literal: true

require "pathname"

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # What an output may say and open, without knowing the command.
        class Console
          # Takes callables, so it can stand in for the command without holding it.
          #
          # @param out [IO] takes a document written to STDOUT
          # @param status [#call] draws a status box on the error stream: level, text
          # @param save_warnings [#call] saves what the run held back from the screen
          # @param browser [#browse]
          def initialize(out:, status:, save_warnings:, browser:)
            @out = out
            @status = status
            @save_warnings = save_warnings
            @browser = browser
          end

          # Says where a file went.
          #
          # @param label [String] such as "JSON report"
          # @param path [String]
          # @return [void]
          def written(label, path) = @status.call(:success, "#{label} written to #{relative(path)}")

          # A warning rather than a failure, since the report exists either way.
          #
          # @param target [String] what could not be opened, as it is named to the user
          # @return [void]
          def could_not_open(target) = @status.call(:warning, "could not open #{target}")

          # Asks the runtime, which knows this platform's opener.
          #
          # @param url [String]
          # @return [Boolean] whether a browser took it
          def browse(url) = @browser.browse(url)

          # Writes it as it is, with no newline added, so a piped document is unchanged.
          #
          # @param document [String]
          # @return [void]
          def print(document) = @out.write(document)

          # Left to the command, which knows where its warnings belong.
          #
          # @return [void]
          def save_warnings = @save_warnings.call

          private

          # As {Command#relative}, which is out of reach from here.
          #
          # @param path [String]
          # @return [String] relative to the working directory
          def relative(path) = Pathname(path).relative_path_from(Dir.pwd).to_s
        end
      end
    end
  end
end
