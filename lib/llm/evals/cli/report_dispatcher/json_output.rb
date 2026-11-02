# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # --format json: the snapshot itself, saved beside the others unless -o
        # names a place for it.
        class JsonOutput < Output
          # Writes the document, or prints it for `-o -`.
          #
          # @see Output#write
          # @param snapshot [Snapshot]
          # @return [void]
          def write(snapshot)
            if snapshot.output.nil? || snapshot.output.empty?
              console.written("JSON report", pipeline.save_json(**snapshot.document))
            else
              path = output_path(snapshot.output, "json")
              document = pipeline.write_json(**snapshot.document, path:)
              path ? console.written("JSON report", path) : console.print(document)
            end
            console.save_warnings
          end
        end
      end
    end
  end
end
