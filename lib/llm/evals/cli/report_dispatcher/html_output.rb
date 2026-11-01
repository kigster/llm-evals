# frozen_string_literal: true

require "uri"

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # --format html: the page, from the same JSON a later `render` would read.
        class HtmlOutput < Output
          # Writes the page, and opens it unless it went to STDOUT.
          #
          # @see Output#write
          # @param snapshot [Snapshot]
          # @return [void]
          def write(snapshot)
            json = json_for(snapshot)
            path = output_path(snapshot.output, "html")
            document = pipeline.write_html(json:, path:)
            path ? console.written("HTML report", path) : console.print(document)
            console.save_warnings
            open_page(path) if snapshot.open && path
          end

          private

          # With autosave the JSON is saved and read back, so the page holds what the file holds.
          #
          # @param snapshot [Snapshot]
          # @return [String] the JSON text
          def json_for(snapshot)
            return pipeline.write_json(**snapshot.document, path: nil) unless snapshot.results[:autosave]

            path = pipeline.save_json(**snapshot.document)
            console.written("JSON results", path)
            File.read(path)
          end

          # Warns when no browser takes it; the page is on disk either way.
          #
          # @param path [String]
          # @return [void]
          def open_page(path)
            console.could_not_open(path) unless console.browse(URI::DEFAULT_PARSER.escape("file://#{path}"))
          end
        end
      end
    end
  end
end
