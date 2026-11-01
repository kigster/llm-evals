# frozen_string_literal: true

RSpec.describe LLM::Evals::Render::Reports::CallStatsTable do
  subject(:rows) { described_class.new(instance_double(LLM::Evals::CallStats, rows: [row])).rows }

  let(:row) { LLM::Evals::CallStats::Row.new(scope: :model, name: "a/b", requests: 3, errors: 1, per_second: 1.5, latency: 0.25, p95: nil) }

  it("formats the cells, with a dash for what was not measured") { expect(rows).to eq([["a/b", 3, 1, "1.50", "0.25s", "-"]]) }
end
