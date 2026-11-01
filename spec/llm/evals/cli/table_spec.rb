# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::Table do
  subject(:table) { described_class.new(pastel: Pastel.new(enabled: false), width: 60) }

  def widths(rendered) = rendered.lines.map { it.chomp.length }.uniq

  it "fills the width it is given" do
    expect(widths(table.render([%w[a 1]], header: %w[model n]))).to eq([60])
  end

  it "right-aligns a numeric column, placeholders aside" do
    expect(table.render([%w[a 1,200], %w[b -]], header: %w[model count])).to include("1,200 │").and match(/ {4}- │/)
  end

  it "left-aligns a column with any text in it" do
    expect(table.render([%w[a 1], %w[b x]], header: %w[model count])).to match(/│ x +│/)
  end

  it "never breaks an unwrapped id, however wide" do
    expect(table.render([["x" * 100, "1"]], header: %w[model n])).to include("x" * 100)
  end

  it "wraps the fill column when asked, with a line between rows" do
    rendered = table.render([["a", "word " * 30]], header: %w[k v], wrap: true)
    expect(widths(rendered)).to eq([60])
    expect(rendered.lines.size).to be > 5
  end

  it "keeps a wrapped column readable on a narrow screen" do
    narrow = described_class.new(pastel: Pastel.new(enabled: false), width: 10)
    expect(widths(narrow.render([["a", "word " * 30]], header: %w[k v], wrap: true)).first).to be > described_class::MIN_WRAP
  end

  it "paints only the highlighted rows" do
    painting = described_class.new(pastel: Pastel.new(enabled: true), width: 60)
    rendered = painting.render([%w[a 1], %w[b 2]], header: %w[k n], highlight: [1])
    expect(rendered).to include(Pastel.new(enabled: true).bold.yellow("b"))
    expect(rendered).not_to include(Pastel.new(enabled: true).bold.yellow("a"))
  end
end
