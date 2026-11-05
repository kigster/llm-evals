# frozen_string_literal: true

module LLM
  module Evals
    module Actions
      # One model at one setting over every case of one dataset, run on a
      # thread pool the gem owns, plus the per-case detail the terminal report
      # needs. Trackers only watch: {Trackers::Local} always, and at most one
      # remote tracker, each told when the experiment starts, when a case
      # finishes, and what the summary was. A tracker that raises is warned
      # about and told nothing more; the cases and their results go on.
      class Experiment
        # What one finished experiment reports back. `means` holds one entry
        # per metric plus "score", the mean of each case's overall value;
        # `usage` is summed over the cases; `permalink` is the remote tracker's
        # page, when it has one.
        #
        # @!attribute [r] model
        #   @return [Models::Model] what ran
        # @!attribute [r] dataset
        #   @return [String] the dataset's name
        # @!attribute [r] name
        #   @return [String] the experiment's {Experiment#name}
        # @!attribute [r] means
        #   @return [Hash{String => Float, nil}] one mean per metric, plus "score"
        # @!attribute [r] results
        #   @return [Array<Results::RunResult>] in the experiment's case order
        # @!attribute [r] errors
        #   @return [Array<String>] one "case: message" per call that raised
        # @!attribute [r] duration
        #   @return [Float] seconds, less an estimate of the time spent on rate limits
        # @!attribute [r] permalink
        #   @return [String, nil] the remote tracker's page
        # @!attribute [r] usage
        #   @return [Stats::Usage] summed over the cases
        Summary = Data.define(:model, :dataset, :name, :means, :results, :errors, :duration, :permalink, :usage) do
          # @return [Float, nil] the mean overall score
          def score = means["score"]

          # @param metric [Scoring::Metric, String]
          # @return [Float, nil]
          def mean(metric) = means[metric.respond_to?(:name) ? metric.name : metric.to_s]

          # @return [Float, nil] the mean seconds of the calls that worked
          def latency = Stats.mean(worked_durations)

          # @return [Float, nil] the 95th percentile seconds of the calls that worked
          def latency_p95 = Stats.percentile(worked_durations, Stats::CallStats::P95)

          # Each working call's own seconds, which {#latency} and {#latency_p95} read.
          #
          # @return [Array<Float>] errored calls are left out
          def worked_durations = results.reject(&:errored?).map(&:duration)

          # The same experiment over one variant's cases. Its duration is the sum
          # of those cases' own, since they overlapped with the others.
          #
          # @param variant [String]
          # @param metrics [Array<Scoring::Metric>] the scorer's
          # @return [Summary]
          def for_variant(variant, metrics)
            chosen = results.select { it.case.variant == variant }
            with(means:    Experiment.means(metrics, chosen),
              results:  chosen,
              errors:   chosen.select(&:failed?).map { "#{it.case.key}: #{it.error}" },
              duration: chosen.sum(&:duration),
              usage:    Experiment.usage(chosen))
          end
        end

        # Averages what the results scored; a failed case has no score and is skipped.
        #
        # @param metrics [Array<Scoring::Metric>]
        # @param results [Array<Results::RunResult>]
        # @return [Hash{String => Float, nil}] one mean per metric, plus "score"
        def self.means(metrics, results)
          scored = results.filter_map(&:score)
          means = metrics.to_h { |metric| [metric.name, metric.combine(scored.map { it.metrics[metric.name] })] }
          means.merge("score" => scored.empty? ? nil : scored.sum(&:value).fdiv(scored.size))
        end

        # Tokens and cost across the results; a raised case has no reply and adds nothing.
        #
        # @param results [Array<Results::RunResult>]
        # @return [Stats::Usage] summed over the results
        def self.usage(results) = results.filter_map(&:reply).map(&:usage).reduce(Stats::Usage.zero, :+)

        attr_reader :model, :adapter, :scorer, :cases, :dataset, :parallelism, :trackers

        # @!attribute [r] model
        #   The model at the setting under test.
        #   @return [Models::Model]

        # @!attribute [r] adapter
        #   Runs each case.
        #   @return [Adapter]

        # @!attribute [r] scorer
        #   Scores each reply.
        #   @return [Scoring::Scorer]

        # @!attribute [r] cases
        #   Sorted by variant, number and id.
        #   @return [Array<Datasets::Case>]

        # @!attribute [r] dataset
        #   The name of the dataset the first case came from.
        #   @return [String]

        # @!attribute [r] parallelism
        #   Cases in flight at once, never below 1.
        #   @return [Integer]

        # @!attribute [r] trackers
        #   Only the enabled ones of those given, in the order given.
        #   @return [Array<Trackers::Base>]

        # @param model [Models::Model]
        # @param cases [Array<Datasets::Case>] all of one dataset
        # @param adapter [Adapter]
        # @param scorer [Scoring::Scorer]
        # @param parallelism [Integer] cases in flight at once
        # @param trackers [Array<Trackers::Base>] told about the run, in this order
        # @raise [ArgumentError] when there are no cases
        def initialize(model:, cases:, adapter:, scorer:, parallelism: 4, trackers: [])
          raise ArgumentError, "an experiment needs at least one case" if cases.empty?

          @model = model
          @cases = cases.sort_by { [it.variant, it.number || 0, it.id] }
          @dataset = cases.first.dataset
          @adapter = adapter
          @scorer = scorer
          @parallelism = [parallelism.to_i, 1].max
          @trackers = trackers.select(&:enabled?)
          @results = {}
          @failed_trackers = []
          @lock = Mutex.new
          @waited = 0.0
        end

        # How reports and trackers tell this experiment from the others of a run.
        #
        # @return [String] e.g. "anthropic/claude-haiku-5.5 effort=low t=0.0 [clear]"
        def name = "#{model} [#{dataset}]"

        # Runs every case, then asks the trackers for a page to link the summary to.
        #
        # @param on_case [#call, nil] called with each finished case's {Results::RunResult}
        # @param stop [#call, nil] asked before each case; truthy leaves the rest unrun
        # @return [Summary]
        def run(on_case: nil, stop: nil)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          adapter.prepare(dataset)
          notify(:start, self)
          errors = run_locally(on_case, stop)
          # An approximation: it assumes waits fell evenly across the workers. Workers
          # that wait while others run did not hold up the run for that long.
          summary = summarize(errors, nil, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started - (@waited / workers))
          urls = notify(:finish, self, summary).map { it&.fetch(:url, nil) }
          summary.with(permalink: urls.compact.first)
        end

        # Runs one case: the adapter, then the scorer. A reply the model failed
        # (`Reply#error`) scores 0 without troubling the scorer; an exception is
        # the transport's and is left to the caller, which counts it as an error.
        #
        # @param kase [Datasets::Case]
        # @return [Results::RunResult]
        # @raise [Error] when the adapter returns anything but a {Results::Reply}
        def evaluate(kase)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          reply, waited = Models::Throttle.measure { adapter.call(kase, model: model) }
          @lock.synchronize { @waited += waited }
          raise Error, "#{adapter.class}#call returned #{reply.class}, not an LLM::Evals::Results::Reply" unless reply.is_a?(Results::Reply)

          score = reply.error? ? Results::Score.failed(scorer.metrics, reply.error) : scorer.call(kase, reply, context: adapter.context(kase))
          Results::RunResult.new(experiment: self,
            case: kase,
            reply: reply,
            score: score,
            duration: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started - waited)
        end

        private

        # Threads worth starting: more than there are cases would only sit idle.
        #
        # @return [Integer]
        def workers = [parallelism, cases.size].min

        # Remembers a result and tells the trackers, under one lock, so a
        # tracker sees results one at a time and in the order they are kept.
        #
        # @param result [Results::RunResult] the finished case
        # @return [Results::RunResult] the same result
        def remember(result)
          @lock.synchronize do
            @results[result.case.key] = result
            notify(:record, result)
          end
          result
        end

        # Tells each tracker that has not failed yet. Callers hold the lock or
        # run outside the case threads, so a failure is noted by one thread.
        #
        # @param callback [Symbol] :start, :record or :finish
        # @return [Array] what each tracker returned, nil for one that raised
        def notify(callback, *)
          (trackers - @failed_trackers).map do |tracker|
            tracker.public_send(callback, *)
          rescue StandardError => e
            @failed_trackers << tracker
            message = "[#{name}] the #{tracker.name} tracker failed in #{callback} and gets nothing more from this experiment: #{e.class}: #{e.message}"
            # Not warn, which prints nothing under -W0.
            $stderr.puts message # rubocop:disable Style/StderrPuts
          end
        end

        # A fixed pool of threads over a queue: `parallelism` cases in flight.
        #
        # @param on_case [#call, nil] called with each finished case's {Results::RunResult}
        # @param stop [#call, nil] asked before each case; truthy leaves the rest unrun
        # @return [Array<String>] one "case: message" per case that raised
        def run_locally(on_case, stop)
          queue = Queue.new
          cases.each { queue << it }
          queue.close
          errors = Queue.new
          Array.new(workers) do
            Thread.new do
              while !stop&.call && (kase = queue.pop)
                result = begin
                  remember evaluate(kase)
                rescue StandardError => e
                  errors << "#{kase.key}: #{e.class}: #{e.message}"
                  remember Results::RunResult.new(experiment: self, case: kase, error: "#{e.class}: #{e.message}")
                end
                on_case&.call(result)
              end
            end
          end.each(&:join)
          Array.new(errors.size) { errors.pop }
        end

        # Freezes what has been remembered so far into a {Summary}, in case order.
        #
        # @param errors [Array<String>, nil] the messages {#run_locally} collected
        # @param permalink [String, nil] the remote tracker's page, when already known
        # @param duration [Float] seconds to report
        # @return [Summary]
        def summarize(errors, permalink, duration)
          results = @lock.synchronize { @results.values }.sort_by { cases.index(it.case) }
          Summary.new(
            model:     model,
            dataset:   dataset,
            name:      name,
            means:     self.class.means(scorer.metrics, results),
            results:   results,
            errors:    Array(errors),
            duration:  duration,
            permalink: permalink,
            usage:     self.class.usage(results)
          )
        end
      end
    end
  end
end
