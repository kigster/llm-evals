# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # No format, or tui: the display and autosave the lineup configures.
        class PipelineOutput < Output
          # @see Output#write
          def write(snapshot, &)
            results = snapshot.results
            result = pipeline.call(**snapshot.document, autosave: results[:autosave], display: results[:display], open: snapshot.open, &)
            console.written("JSON results", result.json_path) if result.json_path
            announce_page(result, snapshot.open) if result.html_path
            console.save_warnings unless results[:display] == "tui" # the terminal view has said so already
          end

          private

          def announce_page(result, open)
            console.written("HTML report", result.html_path)
            console.could_not_open(result.html_path) if open && !result.browser_opened
          end
        end
      end
    end
  end
end
