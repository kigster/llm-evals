# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::StatusBox do
  subject(:box) { described_class.new(width: 40, color: false) }

  it "titles the box by its level, across the whole width" do
    rendered = box.render(:warning, "careful")
    expect(rendered).to include(" Warning ", "careful")
    expect(rendered.lines.map { it.chomp.length }.uniq).to eq([40])
  end

  it "keeps a word wider than the box, cut to fit" do
    expect(box.render(:info, "x" * 60).scan("x").size).to eq(60)
  end

  it "draws without color unless told otherwise" do
    expect(box.render(:info, "text")).not_to include("\e[")
  end

  it "paints when told to" do
    expect(described_class.new(width: 40, color: true).render(:error, "text")).to include("\e[")
  end

  it "refuses a level it does not know" do
    expect { box.render(:shout, "text") }.to raise_error(KeyError)
  end
end
