# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::RunPlanner do
  subject(:planner) { described_class.new(configuration:, config:, options:, trackers:) }

  let(:configuration) { LLM::Evals.configuration }
  let(:config) { configuration.lineup }
  let(:options) { {} }
  let(:trackers) { instance_double(LLM::Evals::CLI::TrackerResolver, for_experiment: []) }

  describe "#datasets" do
    it "means every dataset when none is named" do
      expect(planner.datasets([])).to eq(configuration.discovery.datasets)
    end

    it "splits on commas and drops repeats" do
      expect(planner.datasets(["colors,colors"])).to eq(["colors"])
    end

    it "refuses a suite with no datasets" do
      discovery = instance_double(LLM::Evals::Datasets::Discovery, datasets: [], root: "evals")
      empty = instance_double(LLM::Evals::Runtime::Configuration, discovery:)
      expect { described_class.new(configuration: empty, config:, options:, trackers:).datasets([]) }
        .to raise_error(LLM::Evals::Error, "no datasets under evals")
    end
  end

  describe "#experiments" do
    let(:options) { { case: ["clear"] } }
    let(:contender) { LLM::Evals::Models::Contender.new(model: "fake/echo") }

    it "makes one per dataset and contender, of the selected cases" do
      runs = planner.experiments(["colors"], [contender, contender])
      expect(runs.map(&:dataset)).to eq(%w[colors colors])
      expect(runs.first.cases.map(&:id)).to all(start_with("clear"))
    end
  end

  describe "#parallelism" do
    it { expect(planner.parallelism).to eq(Integer(config.defaults["parallelism"])) }

    context "with the flag" do
      let(:options) { { parallelism: "7" } }

      it { expect(planner.parallelism).to eq(7) }
    end
  end

  describe "#concurrency" do
    it { expect(planner.concurrency).to eq(Etc.nprocessors) }

    {
      "3" => 3,
      "0" => 0
    }.each do |flag, expected|
      it "reads -j #{flag}" do
        expect(described_class.new(configuration:, config:, options: { concurrency: flag }, trackers:).concurrency).to eq(expected)
      end
    end

    it "refuses a negative -j" do
      expect { described_class.new(configuration:, config:, options: { concurrency: "-1" }, trackers:).concurrency }
        .to raise_error(LLM::Evals::Error, "--concurrency must be 0 or more, got -1")
    end

    it "refuses a -j that is no number" do
      expect { described_class.new(configuration:, config:, options: { concurrency: "many" }, trackers:).concurrency }
        .to raise_error(LLM::Evals::Error, '--concurrency must be a whole number, got "many"')
    end
  end
end
