# frozen_string_literal: true

RSpec.describe LLM::Evals::Config do
  describe described_class::Results do
    def from(section) = described_class.from_hash(section, path: "lineup.yml")

    it "defaults every setting" do
      expect(from({})).to have_attributes(autosave: true, display_mode: "tui", destination: File.expand_path("evals/results"), temp_dir: File.expand_path("tmp"))
    end

    it { expect { from("yes") }.to raise_error(LLM::Evals::Error, "lineup.yml: results must be a mapping") }
    it { expect { from("autosave" => "yes") }.to raise_error(LLM::Evals::Error, "lineup.yml: results.autosave must be true or false") }
    it { expect { from("display" => "x") }.to raise_error(LLM::Evals::Error, "lineup.yml: results.display must be one of none, tui, browser") }
  end

  describe described_class::ScoreWeights do
    def from(section) = described_class.from_hash(section, path: "lineup.yml")

    it { expect(from(nil)).to eq({}) }
    it { expect(from("weights" => { cost: -1 })).to eq("cost" => -1) }

    ["x", {}, { "weights" => 3 }].each do |section|
      it "refuses #{section.inspect}" do
        expect { from(section) }.to raise_error(LLM::Evals::Error, "lineup.yml: weighted_score needs a weights: mapping of column to number")
      end
    end
  end

  describe described_class::ErrorLimits do
    def from(limits) = described_class.from_hash({ "abort_after" => limits }, path: "lineup.yml")

    it "reads both limits" do
      expect(from("total" => 5, "percent" => 100)).to have_attributes(total: 5, percent: 100)
    end

    it "builds a new budget each time, since a budget counts one run" do
      limits = from("total" => 5)
      expect(limits.budget).to be_a(LLM::Evals::Actions::ErrorBudget).and have_attributes(total: 5, percent: nil)
      expect(limits.budget).not_to equal(limits.budget)
    end

    ["x", {}, { "abort_after" => 3 }].each do |section|
      it "refuses the section #{section.inspect}" do
        expect { described_class.from_hash(section, path: "lineup.yml") }
          .to raise_error(LLM::Evals::Error, "lineup.yml: errors needs an abort_after: mapping of total and percent")
      end
    end

    [nil, 0, -1, 1.5, "5"].each do |total|
      it "refuses a total of #{total.inspect}" do
        expect { from("total" => total) }.to raise_error(LLM::Evals::Error, "lineup.yml: errors.abort_after.total must be a whole number above 0")
      end
    end

    [0, -1, 101, "50"].each do |percent|
      it "refuses a percent of #{percent.inspect}" do
        expect { from("total" => 1, "percent" => percent) }
          .to raise_error(LLM::Evals::Error, "lineup.yml: errors.abort_after.percent must be above 0 and at most 100")
      end
    end
  end

  describe described_class::ContenderBuilder do
    subject(:builder) { described_class.new(defaults: { "effort" => "default", "temperature" => 0.2, "max_tokens" => 10 }, overrides:) }

    let(:overrides) { {} }

    it "uses the defaults under an entry's own settings" do
      expect(builder.call("a/b", { "max_tokens" => 20 }).first).to have_attributes(model: "a/b", effort: "default", temperature: 0.2, max_tokens: 20)
    end

    it "makes one contender per effort and temperature" do
      built = builder.call("a/b", { "effort" => %w[low high], "temperature" => [0, 1] })
      expect(built.map { [it.effort, it.temperature] }).to eq([["low", 0], ["low", 1], ["high", 0], ["high", 1]])
    end

    it "passes the provider along" do
      expect(builder.call("a/b", provider: :typesafe).first.provider).to eq(:typesafe)
    end

    context "with overrides, nil ones ignored" do
      let(:overrides) { { "effort" => "high", "temperature" => nil } }

      it { expect(builder.call("a/b", { "effort" => "low" }).first).to have_attributes(effort: "high", temperature: 0.2) }
    end
  end

  describe "#validate!" do
    subject(:config) { described_class.new(path) }

    let(:dir) { Dir.mktmpdir }
    let(:path) { File.join(dir, "config.yml") }

    after { FileUtils.remove_entry(dir) }

    it "passes a file with no such sections" do
      expect { config.validate! }.not_to raise_error
    end

    {
      "results:\n  display: terminal\n"         => /results\.display/,
      "errors:\n  abort_after:\n    total: 0\n" => /errors\.abort_after\.total/,
      "weighted_score: 3\n"                     => /needs a weights/
    }.each do |yaml, message|
      it "fails on #{yaml.lines.first.strip}" do
        File.write(path, yaml)
        expect { config.validate! }.to raise_error(LLM::Evals::Error, message)
      end
    end
  end
end
