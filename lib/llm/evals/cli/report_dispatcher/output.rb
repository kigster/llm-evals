# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      class ReportDispatcher
        # One way of delivering a run.
        class Output
          # @param pipeline [LLM::Evals::Render::Reports::Pipeline]
          # @param console [Console]
          # @param invocation [Dry::CLI::UI::Invocation] names the default files
          def initialize(pipeline:, console:, invocation:)
            @pipeline = pipeline
            @console = console
            @invocation = invocation
          end

          # @param snapshot [Snapshot]
          # @yield [report] draw the decoded report in the terminal, for an output that does
          # @return [void]
          def write(snapshot, &) = raise NotImplementedError, "#{self.class} must implement #write"

          private

          attr_reader :pipeline, :console

          # @param output [String, nil] what -o was given
          # @param extension [String]
          # @return [String, nil] nil means STDOUT
          def output_path(output, extension)
            return nil if output == "-"
            return pipeline.report_path(File.dirname(@invocation.report_path("")), extension) if output.nil? || output.empty?

            @invocation.report_path(output).sub(/\.log\z/, ".#{extension}")
          end
        end
      end
    end
  end
end
