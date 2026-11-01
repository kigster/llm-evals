# frozen_string_literal: true

RSpec.describe LLM::Evals::ConfigUpgrade do
  subject(:upgraded) { described_class.new(text, path: "lineup.yml").call }

  let(:text) do
    <<~YAML
      # The lineup
      request_types: [prompt]
      vendors: # through OpenRouter
        anthropic:
          # the big one
          - model: claude-opus-5
            effort: [low, high]
        openai:
          - model: gpt-6.1-sol

      # Jev itself
      direct:
        typesafe:
          - model: jev-latest
      results:
        autosave: false
    YAML
  end

  it "moves models under provider sections" do
    expect(YAML.safe_load(upgraded)).to eq(
      "request_types" => ["prompt"],
      "openrouter"    => { "vendors" => { "anthropic" => { "models" => [{ "model" => "claude-opus-5", "effort" => %w[low high] }] },
                                          "openai"    => { "models" => [{ "model" => "gpt-6.1-sol" }] } } },
      "typesafe"      => { "models" => [{ "model" => "jev-latest" }] },
      "results"       => { "autosave" => false }
    )
  end

  it("keeps the comments") { expect(upgraded).to include("# The lineup", "# through OpenRouter", "# the big one", "# Jev itself") }

  it "reads back as the same contenders" do
    Tempfile.create("lineup") do |file|
      file.write(upgraded)
      file.flush
      expect(LLM::Evals::Config.new(file.path).contenders.map(&:key)).to eq(
        %w[anthropic/claude-opus-5 anthropic/claude-opus-5 openai/gpt-6.1-sol typesafe:typesafe/jev-latest]
      )
    end
  end

  context "with a file in the new shape" do
    let(:text) { "openrouter:\n  vendors: {}\n" }

    it { expect(described_class.new(text, path: "lineup.yml")).not_to be_needed }
  end

  context "with a form the rewrite cannot prove" do
    let(:text) { "vendors: { anthropic: [{ model: a }] }\n" }

    it { expect { upgraded }.to raise_error(LLM::Evals::Error, /move them by hand/) }
  end

  context "with both shapes" do
    let(:text) { "vendors:\n  a:\n    - model: b\nopenrouter:\n  vendors: {}\n" }

    it { expect { upgraded }.to raise_error(LLM::Evals::Error, /a section named openrouter/) }
  end

  context "with text that is not YAML" do
    let(:text) { "a: [" }

    it { expect { upgraded }.to raise_error(LLM::Evals::Error, /lineup.yml: not valid YAML/) }
  end

  context "with a list at the top" do
    let(:text) { "- a\n" }

    it { expect { upgraded }.to raise_error(LLM::Evals::Error, /lineup.yml: a lineup must be a mapping/) }
  end
end
