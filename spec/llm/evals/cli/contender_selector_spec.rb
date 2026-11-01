# frozen_string_literal: true

require "spec_helper"

RSpec.describe LLM::Evals::CLI::ContenderSelector do
  subject(:selector) { described_class.new(config:, providers:, warnings:) }

  let(:config) { instance_double(LLM::Evals::Config, path: "lineup.yml", request_types: [:text], contenders: [], contenders_for: [contender]) }
  let(:contender) { instance_double(LLM::Evals::Models::Contender) }
  let(:providers) { instance_double(LLM::Evals::Providers::Registry, for: nil, admit: [[contender], []]) }
  let(:warnings) { LLM::Evals::Results::Warnings.new }

  it "splits -m on commas and passes the setting flags" do
    selector.call(["a/b,c/d"], effort: "low")
    expect(config).to have_received(:contenders_for).with(%w[a/b c/d], { "effort" => "low", "temperature" => nil, "max_tokens" => nil })
  end

  it "refuses a lineup that names nothing" do
    expect { selector.call([], {}) }.to raise_error(LLM::Evals::Error, /no models: list some under a provider in lineup\.yml/)
  end

  context "when every contender is refused" do
    before { allow(providers).to receive(:admit).and_return([[], ["a/b: no text"]]) }

    it { expect { selector.call(["a/b"], {}) }.to raise_error(LLM::Evals::Error, "no admitted models: a/b: no text") }

    it "records the refusal" do
      begin
        selector.call(["a/b"], {})
      rescue LLM::Evals::Error
        nil
      end
      expect(warnings.count).to eq(1)
    end
  end
end
