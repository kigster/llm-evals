# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # No format, or tui: the display and autosave the lineup configures.
        class PipelineOutput < Output
          # Lets the pipeline decide, then says what it wrote.
          #
          # @see Output#write
          # @param snapshot [Snapshot]
          # @yield [report] draw the decoded report in the terminal, when the display does
          # @return [void]
          def write(snapshot, &)
            results = snapshot.results
            result = pipeline.call(**snapshot.document, autosave: results[:autosave], display: results[:display], open: snapshot.open, &)
            console.written("JSON results", result.json_path) if result.json_path
            announce_page(result, snapshot.open) if result.html_path
            console.save_warnings unless Config::TERMINAL_DISPLAYS.include?(results[:display]) # the terminal view has said so already
          end

          private

          # Says where the page went, and warns when it would not open.
          #
          # @param result [LLM::Evals::Render::Reports::Pipeline::Result]
          # @param open [Boolean] whether opening it was asked for
          # @return [void]
          def announce_page(result, open)
            console.written("HTML report", result.html_path)
            console.could_not_open(result.html_path) if open && !result.browser_opened
          end
        end
      end
    end
  end
end
