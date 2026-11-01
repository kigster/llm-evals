# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # What the report's page shows, worked out from a decoded snapshot; the
          # template and its markup stay with {HTML}.
          class ViewModel
            include Format

            # @return [JSON::Loaded] the decoded snapshot behind every answer here
            attr_reader :report

            # Shares one {Ranking} between the standings and every dataset section.
            #
            # @param report [JSON::Loaded]
            def initialize(report)
              @report = report
              @ranking = Ranking.new(metrics: report.metrics, weighted_score: report.weighted_score)
            end

            # The page's heading.
            #
            # @return [String]
            def report_title = "#{configuration_name} evaluation report"

            # The suite's name, as the snapshot recorded it.
            #
            # @return [String]
            def configuration_name = report.suite

            # @return [Array<Actions::Experiment::Summary>] every experiment in the snapshot
            def summaries = report.summaries

            # @return [Scoring::WeightedScore, nil] nil when the lineup set no weights
            def weighted_score = report.weighted_score

            # Across every result in the report, with tokens and cost already formatted for display.
            #
            # @return [Hash{Symbol => Object}] health counts and cost for the template
            def health_summary
              usage = summaries.map(&:usage).reduce(Stats::Usage.zero, :+)
              failed = results.count { Ranking.failed?(it) }
              { successful:    results.size - failed,
                total:         results.size,
                failed:,
                input_tokens:  tokens(usage.input_tokens),
                output_tokens: tokens(usage.output_tokens),
                cost:          money(usage.cost_usd) }
            end

            # The whole page's ranking, built fresh on each call.
            #
            # @return [Hash{Symbol => Object}] see {GlobalStandings#to_h}
            def global_standings = GlobalStandings.new(summaries, @ranking).to_h

            # One section per dataset, in name order.
            #
            # @return [Array<Hash{Symbol => Object}>] see {DatasetSection#to_h}
            def dataset_reports
              summaries.group_by(&:dataset).sort.map { |name, group| DatasetSection.new(name, group, @ranking).to_h }
            end

            # Details prefer the error of a run that raised over its score's diagnostics.
            #
            # @param kase [Datasets::Case]
            # @param group [Array<Actions::Experiment::Summary>]
            # @return [Array<Hash{Symbol => Object}>] runs and display values for one case
            def case_results(kase, group)
              group.flat_map(&:results).select { it.case.key == kase.key }.map do |run|
                details = run.failed? ? { "error" => run.error } : run.score&.diagnostics
                { run:, status: status(run), details: details || {} }
              end
            end

            # Hides the entry's shape from the template.
            #
            # @param entry [Hash{Symbol => Object}]
            # @return [Float, nil]
            def ranking_value(entry) = entry[:ranking]

            # The name of what ranks when no weighted score does.
            #
            # @return [String]
            def primary_metric = @ranking.primary_metric

            # The sentence under the standings explaining how they were ordered.
            #
            # @return [String]
            def weight_description
              weighted_score ? "Weighted score from the lineup; chart order runs worst to best." : "Ranked by #{primary_metric}; chart order runs worst to best."
            end

            private

            # @return [Array<Results::RunResult>] every run in the report
            def results = summaries.flat_map(&:results)

            # The run's error, the model's failure, its percentage, or "No score".
            #
            # @param run [Results::RunResult]
            # @return [String]
            def status(run)
              return run.error if run.failed?
              return run.reply.error if run.reply&.error?

              run.score ? percent(run.score.value) : "No score"
            end
          end
        end
      end
    end
  end
end
