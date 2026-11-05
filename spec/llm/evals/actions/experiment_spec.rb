# frozen_string_literal: true

RSpec.describe LLM::Evals::Actions::Experiment do
  subject(:experiment) do
    described_class.new(model: model, cases: cases, adapter: adapter, scorer: scorer, parallelism: 2)
  end

  let(:configuration) { LLM::Evals.configuration }
  let(:adapter) { configuration.adapter }
  let(:scorer) { configuration.scorer }
  let(:cases) { configuration.discovery.cases(dataset: "colors") }
  let(:model) { LLM::Evals::Testing::FakeModel.new(junk: ["vague/002"], wrong: { "clear/001" => { "trim" => "pink" } }) }

  its(:name) { is_expected.to eq("fake/echo effort=default t=0.2 [colors]") }
  its(:dataset) { is_expected.to eq("colors") }
  it { expect { described_class.new(model: model, cases: [], adapter: adapter, scorer: scorer) }.to raise_error(ArgumentError, /at least one case/) }

  describe "the run's time" do
    it "leaves out waits on the limits, shared among the workers" do
      allow(adapter).to(receive(:call).and_wrap_original { |call, *args, **opts| sleep(0.1); call.call(*args, **opts) })
      allow(LLM::Evals::Models::Throttle).to(receive(:measure).and_wrap_original { |measure, &block| [measure.call(&block).first, 0.1] })
      expect(experiment.run.duration).to be_within(0.09).of(0)
    end
  end

  describe "#run" do
    subject(:summary) { experiment.run(on_case: ->(result) { ticks << result }) }

    let!(:ticks) { [] }

    its(:errors) { is_expected.to eq([]) }
    its(:permalink) { is_expected.to be_nil }
    its("results.size") { is_expected.to eq(4) }
    it { expect(summary.means["exact_match"]).to eq(0.5) }
    it { expect(summary.means["field_accuracy"]).to be_within(0.001).of(((2.0 / 3) + 1 + 1 + 0) / 4) }
    it { expect(summary.mean(scorer.primary)).to eq(summary.means["field_accuracy"]) }
    it { expect(summary.score).to eq(summary.means["field_accuracy"]) }
    it { expect(summary.means["restraint"]).to eq(0.5) }
    it { expect(summary.usage).to have_attributes(input_tokens: 400, output_tokens: 40) }
    it { expect(summary.results.map { it.case.id }).to eq(%w[clear/001 clear/002 vague/001 vague/002]) }

    it "diagnoses the wrong field" do
      expect(summary.results.first.score.diagnostics).to eq("trim" => { want: "white", got: "pink" })
    end

    it "scores a junk reply as zero rather than failing the case" do
      result = summary.results.last
      expect(result.reply).to be_error
      expect(result.score).to have_attributes(value: 0.0, diagnostics: { "error" => "reply is not JSON" })
    end

    it "reports each finished case" do
      summary
      expect(ticks.size).to eq(4)
    end

    it "reports a junk reply as errored, and the good ones as not" do
      summary
      expect(ticks.count(&:errored?)).to eq(1)
    end

    context "when the adapter raises" do
      before { allow(adapter).to receive(:call).and_raise(RuntimeError, "out of credits") }

      it "reports each case as errored" do
        summary
        expect(ticks).to all(be_errored)
      end

      it "counts the error and scores nothing" do
        expect(summary.errors).to all(match(%r{colors/\w+/00\d: RuntimeError: out of credits}))
        expect(summary.errors.size).to eq(4)
        expect(summary.means.values).to all(be_nil)
        expect(summary.results).to all(be_failed)
      end
    end

    context "when the adapter returns something else" do
      before { allow(adapter).to receive(:call).and_return({}) }

      it { expect(summary.errors.first).to include("returned Hash, not an LLM::Evals::Results::Reply") }
    end
  end

  context "with trackers" do
    subject(:experiment) do
      described_class.new(model: model, cases: cases, adapter: adapter, scorer: scorer, parallelism: 1, trackers: [first, second, off])
    end

    let(:first) { RecordingTracker.new(url: "https://first/exp") }
    let(:second) { RecordingTracker.new(url: nil) }
    let(:off) { RecordingTracker.new(enabled: false) }

    it "tells each enabled tracker about the run, in order, and keeps the first URL" do
      summary = experiment.run
      expect(first.events.map(&:first)).to eq([:start, :record, :record, :record, :record, :finish])
      expect(first.events.select { it.first == :record }.map { it.last.case.id }).to eq(%w[clear/001 clear/002 vague/001 vague/002])
      expect(first.events.last.last).to be_a(described_class::Summary)
      expect(second.events.map(&:first)).to eq(first.events.map(&:first))
      expect(off.events).to eq([])
      expect(summary.permalink).to eq("https://first/exp")
      expect(experiment.trackers).to eq([first, second])
    end

    it "records a failed case too" do
      allow(adapter).to receive(:call).and_raise(IOError, "closed")
      experiment.run
      expect(first.events.select { it.first == :record }.map(&:last)).to all(be_failed)
    end
  end

  context "when a tracker raises" do
    subject(:experiment) do
      described_class.new(model: model, cases: cases, adapter: adapter, scorer: scorer, parallelism: 2, trackers: [watcher, failing])
    end

    let(:watcher) { RecordingTracker.new(url: "https://watcher/exp") }
    let(:failing) { failing_tracker.new }
    let(:healthy) { described_class.new(model: model, cases: cases, adapter: adapter, scorer: scorer, parallelism: 2).run }
    # A remote tracker whose service is down for one callback.
    let(:failing_tracker) do
      broken = phase
      Class.new(RecordingTracker) do
        def self.name = "Flaky"

        define_method(broken) do |*args|
          super(*args)
          raise IOError, "503 Service Unavailable"
        end
      end
    end

    def outcome(summary) = summary.results.map { [it.case.key, it.errored?, it.score&.value] }

    def run_quietly
      summary = nil
      expect { summary = experiment.run }.to output(/flaky tracker/).to_stderr
      summary
    end

    shared_examples "a tracker that only watches" do
      it "keeps every case's result as if the tracker were not there" do
        summary = run_quietly
        expect(outcome(summary)).to eq(outcome(healthy))
        expect(summary.errors).to eq(healthy.errors)
      end

      it "still tells the other trackers everything, once per case" do
        run_quietly
        expect(watcher.events.map(&:first)).to eq([:start, *Array.new(cases.size, :record), :finish])
      end

      it "warns once, naming the experiment, the tracker, the callback and the error" do
        expect { experiment.run }.to output(
          "[#{experiment.name}] the flaky tracker failed in #{phase} and gets nothing more from this experiment: " \
          "IOError: 503 Service Unavailable\n"
        ).to_stderr
      end

      it "tells the failed tracker nothing more" do
        run_quietly
        expect(failing.events.map(&:first).count(phase)).to eq(1)
        expect(failing.events.map(&:first).last).to eq(phase)
      end
    end

    context "when it fails to record a case" do
      let(:phase) { :record }

      it_behaves_like "a tracker that only watches"

      it "still writes the local log, with each case once" do
        dir = Dir.mktmpdir
        local = LLM::Evals::Trackers::Local.new(dir:)
        run = described_class.new(model:, cases:, adapter:, scorer:, parallelism: 2, trackers: [local, failing])
        expect { run.run }.to output(/flaky tracker failed in record/).to_stderr
        logs = Dir[File.join(dir, "*.json")]
        expect(logs.size).to eq(1)
        document = JSON.parse(File.read(logs.first))
        expect(document.fetch("results").map { it.fetch("case") }).to match_array(cases.map(&:key))
      ensure
        FileUtils.remove_entry(dir)
      end
    end

    context "when it fails to start" do
      let(:phase) { :start }

      it_behaves_like "a tracker that only watches"
    end

    context "when it fails to finish" do
      let(:phase) { :finish }

      it_behaves_like "a tracker that only watches"

      it "keeps the other tracker's link" do
        expect(run_quietly.permalink).to eq("https://watcher/exp")
      end
    end
  end
end
