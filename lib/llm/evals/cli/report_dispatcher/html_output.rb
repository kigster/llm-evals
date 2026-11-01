# frozen_string_literal: true

require "uri"

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # --format html: the page, from the same JSON a later `render` would read.
        class HtmlOutput < Output
          # @see Output#write
          def write(snapshot)
            json = json_for(snapshot)
            path = output_path(snapshot.output, "html")
            document = pipeline.write_html(json:, path:)
            path ? console.written("HTML report", path) : console.print(document)
            console.save_warnings
            open_page(path) if snapshot.open && path
          end

          private

          def json_for(snapshot)
            return pipeline.write_json(**snapshot.document, path: nil) unless snapshot.results[:autosave]

            path = pipeline.save_json(**snapshot.document)
            console.written("JSON results", path)
            File.read(path)
          end

          def open_page(path)
            console.could_not_open(path) unless console.browse(URI::DEFAULT_PARSER.escape("file://#{path}"))
          end
        end
      end
    end
  end
end
