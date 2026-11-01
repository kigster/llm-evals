# frozen_string_literal: true

RSpec.describe "evals", type: :aruba do
  it "prints help and exits 0 without arguments" do
    run_command_and_stop("evals")
    expect(last_command_started).to have_output(/demo/)
  end

  it "prints the version" do
    run_command_and_stop("evals version")
    expect(last_command_started).to have_output(LLM::Evals::VERSION)
  end

  it "runs the demo jobs" do
    run_command_and_stop("evals demo --jobs 2 --steps 3 --threads 2")
    expect(last_command_started).to have_output(/Finished 2 jobs of 3 steps each/)
  end

  it "prints a zsh completion script" do
    run_command_and_stop("evals completion zsh")
    expect(last_command_started).to have_output(/evals\(\)/)
  end

  it "fails on a non-numeric job count" do
    run_command_and_stop("evals demo --jobs many", fail_on_error: false)
    expect(last_command_started).to have_exit_status(1)
  end
end
