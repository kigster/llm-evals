# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::ExperimentPool do
  subject(:pool) { described_class.new(console: nil, colors: LLM::Evals::CLI::ModelColors.new, warnings:) }

  let(:warnings) { LLM::Evals::Results::Warnings.new }
  let(:bars) { instance_double(LLM::Evals::CLI::ProgressBars) }
  let(:handle) { Class.new { def advance(as:) = (@advances ||= []) << as; attr_reader :advances }.new }
  let(:multi) do
    bar = handle
    Class.new { define_method(:progress) { |_label, **, &block| block.call(bar) } }.new
  end
  let(:summary) { instance_double(LLM::Evals::Actions::Experiment::Summary, name: "exp", errors: ["boom"]) }
  let(:result) { instance_double(LLM::Evals::Results::RunResult, errored?: true) }
  let(:run) { instance_double(LLM::Evals::Actions::Experiment, cases: [1]) }

  before do
    allow(LLM::Evals::CLI::ProgressBars).to receive_messages(for: bars, labels: ["label"])
    allow(bars).to receive(:run).and_yield(multi)
    allow(run).to receive(:run) do |on_case:, **|
      on_case.call(result)
      summary
    end
  end

  it "returns the summaries and how long they took" do
    outcome = pool.call([run], concurrency: 2)
    expect(outcome.summaries).to eq([summary])
    expect(outcome.seconds).to be >= 0
  end

  it "records each experiment's errors by name" do
    pool.call([run], concurrency: 2)
    expect(warnings.count).to eq(1)
  end

  it "counts a failed case on its bar" do
    pool.call([run], concurrency: 2)
    expect(handle.advances).to eq([:failed])
  end

  it "runs them all together at concurrency 0" do
    pool.call([run], concurrency: 0)
    expect(bars).to have_received(:run).with("Running 1 experiment", concurrent: true)
  end

  it "pluralizes the headline and passes the cap" do
    pool.call([run, run], concurrency: 2)
    expect(bars).to have_received(:run).with("Running 2 experiments", concurrent: 2)
  end

  it "charges each result to the budget" do
    budget = LLM::Evals::Actions::ErrorBudget.new(total: 1)
    pool.call([run], concurrency: 1, budget:)
    expect(budget).to be_spent
  end

  context "with a streak" do
    let(:streak) { LLM::Evals::Actions::ErrorStreak.new(limit: 1) }
    let(:stops) { [] }

    before do
      allow(bars).to receive(:pausing).and_yield
      allow(run).to receive(:run) do |on_case:, stop:|
        on_case.call(result)
        stops << stop.call
        summary
      end
    end

    it "stops the workers when the pause says so, with the bars still" do
      pool.call([run], concurrency: 1, streak:, pause: ->(_failures) { false })
      expect(stops).to eq([true])
      expect(bars).to have_received(:pausing)
    end

    it "lets them carry on when the pause says so" do
      pool.call([run], concurrency: 1, streak:, pause: ->(_failures) { true })
      expect(stops).to eq([false])
    end
  end

  it "skips an experiment once the budget is spent" do
    budget = instance_double(LLM::Evals::Actions::ErrorBudget, spent?: true)
    expect(pool.call([run], concurrency: 1, budget:).summaries).to be_empty
    expect(run).not_to have_received(:run)
  end
end
