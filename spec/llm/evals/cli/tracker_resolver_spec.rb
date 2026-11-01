# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::TrackerResolver do
  subject(:resolver) { described_class.new(configuration:, config:, options:, err:, env:) }

  let(:remote_class) do
    Class.new(LLM::Evals::Tracker) do
      def self.tracker_name = "remote"
    end
  end
  let(:registry) { instance_double(LLM::Evals::Trackers::Registry, choose: [remote_class, "--tracker"]) }
  let(:configuration) { instance_double(LLM::Evals::Configuration, trackers: registry, name: "suite", project: "suite-project") }
  let(:config) { instance_double(LLM::Evals::Config, tracker: nil, project: "lineup-project", tracker_options: { "a" => 1 }) }
  let(:options) { {} }
  let(:err) { StringIO.new }
  let(:env) { { "BRAINTRUST_PROJECT_ID" => " id-1 " } }

  describe "#project" do
    it { expect(resolver.project).to eq("lineup-project") }

    context "with --project" do
      let(:options) { { project: "flag" } }

      it { expect(resolver.project).to eq("flag") }
    end

    context "when the lineup names none" do
      let(:config) { instance_double(LLM::Evals::Config, project: nil) }

      it { expect(resolver.project).to eq("suite-project") }
    end
  end

  describe "#remote" do
    it "chooses once per run" do
      2.times { resolver.remote }
      expect(registry).to have_received(:choose).once.with(flag: nil, config: nil, env:, local: nil)
    end

    it "stays quiet without --verbose" do
      resolver.remote
      expect(err.string).to be_empty
    end

    context "with --verbose" do
      let(:options) { { verbose: true } }

      it "says what was chosen, and why" do
        resolver.remote
        expect(err.string).to eq("tracker: remote, because --tracker\n")
      end
    end

    context "with --verbose and nothing chosen" do
      let(:options) { { verbose: true } }
      let(:registry) { instance_double(LLM::Evals::Trackers::Registry, choose: nil) }

      it "remembers the nil, and says none" do
        2.times { expect(resolver.remote).to be_nil }
        expect(err.string).to eq("tracker: none\n")
      end
    end
  end

  describe "#for_experiment" do
    it "gives the local log first, then the remote with its settings" do
      local, remote = resolver.for_experiment
      expect(local).to be_a(LLM::Evals::Trackers::Local)
      expect(remote).to be_a(remote_class)
      expect(remote.context).to include(suite: "suite", project: "lineup-project", project_id: "id-1", options: { "a" => 1 })
    end

    it "builds new instances each time" do
      expect(resolver.for_experiment.first).not_to equal(resolver.for_experiment.first)
    end

    context "with --project, which outranks the environment's project" do
      let(:options) { { project: "flag" } }

      it { expect(resolver.for_experiment.last.context[:project_id]).to be_nil }
    end

    context "with no remote tracker" do
      let(:registry) { instance_double(LLM::Evals::Trackers::Registry, choose: nil) }

      it { expect(resolver.for_experiment.map(&:class)).to eq([LLM::Evals::Trackers::Local]) }
    end
  end
end
