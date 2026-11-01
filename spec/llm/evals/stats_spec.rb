# frozen_string_literal: true

RSpec.describe LLM::Evals::Stats do
  describe ".percentile" do
    it("takes the nearest rank") { expect(described_class.percentile((1..100).to_a, 0.95)).to eq(95) }
    it("is nil with no values") { expect(described_class.percentile([], 0.95)).to be_nil }
  end

  describe ".mean" do
    it("averages") { expect(described_class.mean([1, 2])).to eq(1.5) }
    it("is nil with no values") { expect(described_class.mean([])).to be_nil }
  end
end
