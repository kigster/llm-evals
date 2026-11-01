# frozen_string_literal: true

require "pathname"

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # What an output may say and open, without knowing the command.
        class Console
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

          # @param label [String] such as "JSON report"
          # @param path [String]
          # @return [void]
          def written(label, path) = @status.call(:success, "#{label} written to #{relative(path)}")

          # @param target [String] what could not be opened, as it is named to the user
          # @return [void]
          def could_not_open(target) = @status.call(:warning, "could not open #{target}")

          # @param url [String]
          # @return [Boolean] whether a browser took it
          def browse(url) = @browser.browse(url)

          # @param document [String]
          # @return [void]
          def print(document) = @out.write(document)

          # @return [void]
          def save_warnings = @save_warnings.call

          private

          def relative(path) = Pathname(path).relative_path_from(Dir.pwd).to_s
        end
      end
    end
  end
end
