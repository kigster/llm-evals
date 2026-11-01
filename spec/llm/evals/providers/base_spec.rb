# frozen_string_literal: true

RSpec.describe LLM::Evals::Providers::Base do
  subject(:provider) { described_class.new }

  its(:name) { is_expected.to eq("base") }
  its(:catalog) { is_expected.to be_nil }
  its(:request_type_description) { is_expected.to eq("") }
  it { is_expected.not_to be_direct }
  it { expect { provider.request_type }.to raise_error(NotImplementedError, /prompt, typesafe/) }
  it { expect(provider.setup!(app_name: "x")).to be_nil }
  it { expect(provider.unknown(%w[a b])).to eq([]) }

  it "requires complete to be overridden" do
    model = LLM::Evals::Models::Model.new(id: "x", provider: provider)
    expect { model.complete(user: "x") }.to raise_error(NotImplementedError, /Completion/)
  end

  it "answers no typed questions by default" do
    provider = Class.new(described_class).new
    expect { provider.ask(nil, state: "s", questions: {}) }.to raise_error(NotImplementedError, /does not answer typed questions/)
  end
end
