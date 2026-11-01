# frozen_string_literal: true

# The top of LLM::Evals holds modules. A new class belongs in one of them, so a
# file here without a folder of its own has lost its way.
RSpec.describe "the LLM::Evals namespace" do
  let(:root) { File.expand_path("../../../lib/llm/evals", __dir__) }
  let(:without_a_folder) { %w[launcher version] }

  it "has a folder for every file, the launcher and version aside" do
    names = Dir[File.join(root, "*.rb")].map { File.basename(it, ".rb") }
    expect(names.reject { File.directory?(File.join(root, it)) }).to match_array(without_a_folder)
  end
end
