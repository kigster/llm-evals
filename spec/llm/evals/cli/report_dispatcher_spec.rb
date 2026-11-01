# frozen_string_literal: true

require "spec_helper"

RSpec.describe LLM::Evals::CLI::ReportDispatcher do
  describe described_class::Output do
    it "leaves #write to its subclasses" do
      output = described_class.new(pipeline: nil, console: nil, invocation: nil)
      expect { output.write(nil) }.to raise_error(NotImplementedError, /must implement #write/)
    end
  end

  describe described_class::Console do
    subject(:console) { described_class.new(out:, status:, save_warnings: -> { saved << true }, browser:) }

    let(:out) { StringIO.new }
    let(:said) { [] }
    let(:saved) { [] }
    let(:status) { ->(level, text) { said << [level, text] } }
    let(:browser) { instance_double(LLM::Evals::Runtime::Environment, browse: false) }

    it "names a written file relative to the working directory" do
      console.written("JSON report", File.join(Dir.pwd, "log", "a.json"))
      expect(said).to eq([[:success, "JSON report written to log/a.json"]])
    end

    it "warns about what would not open" do
      console.could_not_open("a.html")
      expect(said).to eq([[:warning, "could not open a.html"]])
    end

    it "prints a document, saves warnings, and asks the browser" do
      console.print("doc")
      console.save_warnings
      expect([out.string, saved, console.browse("u")]).to eq(["doc", [true], false])
    end
  end
end
