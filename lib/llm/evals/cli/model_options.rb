# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # The flags of every command that calls a model.
      module ModelOptions
        # @param command [Class<Command>]
        # @return [void]
        def self.apply(command)
          command.extend(Dry::CLI::UI::Flags)
          command.flags(:dry_run, :output)
          command.option :models,
            type:    :array,
            aliases: ["-m"],
            default: [],
            desc:    "Model ids, comma-separated, instead of the config file's vendors"
          command.option :dataset,
            type:    :array,
            aliases: ["-d"],
            default: [],
            desc:    "Datasets, comma-separated; every dataset when omitted. Each model runs on each"
          command.option :config, aliases: ["-C"], desc: "The lineup file (default: the suite's .llm-evals.config.yml)"
          command.option :effort, aliases: ["-e"], desc: "Reasoning effort: default, or one the provider accepts (overrides the config file)"
          command.option :temperature, aliases: ["-t"], desc: "Sampling temperature, or 'default' to send none (overrides the config file)"
          command.option :max_tokens, desc: "Output token cap, reasoning included (overrides the config file)"
          command.option :case,
            type:    :array,
            aliases: ["-c"],
            default: [],
            desc:    "Only these cases, by id prefix: -c clear or -c clear/003,vague/001"
          command.option :parallelism, aliases: ["-p"], desc: "Cases in flight at once, per model (default: the config's defaults.parallelism)"
          command.option :concurrency,
            aliases: ["-j"],
            desc:    "Experiments running at once; 0 runs them all together (default: the number of CPUs)"
          command.option :project,
            desc: "Braintrust project name; default is the BRAINTRUST_PROJECT_ID project, else the config file's project"
          command.option :open,
            type:    :boolean,
            default: true,
            desc:    "Open the best experiment in the browser when done (no effect with --local)"
          command.option :scores,
            type:    :boolean,
            default: false,
            desc:    "Also print every experiment by score, with its cost and its tracker's link"
          command.option :totals,
            values:  %w[overall variant both],
            default: "overall",
            desc:    "Group TUI totals by overall results, case variant or both"
          command.option :format,
            values: %w[tui html json],
            desc:   "Override the configured display: tui, html or json"
          command.option :display,
            values: %w[none tui browser],
            desc:   "Override results.display from the lineup"
          command.option :autosave,
            type:    :boolean,
            default: nil,
            desc:    "Save a JSON snapshot regardless of results.autosave"
          command.option :destination,
            desc: "Override results.destination"
          command.option :temp_dir,
            desc: "Override results.temp_dir"
          command.option :local,
            type:    :boolean,
            default: false,
            desc:    "No remote tracker: results go to log/ only (still calls the models)"
          command.option :tracker,
            desc: "The remote tracker: braintrust, logfire, none, or one the suite registers " \
                  "(default: the config's tracker:, else the one whose key is in the environment)"
        end
      end
    end
  end
end
