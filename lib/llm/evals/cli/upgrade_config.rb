# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Moves a lineup file to the current format, keeping its comments and
      # leaving the old file beside it as <file>.bak.
      class UpgradeConfig < Command
        desc "Rewrite the config file in the current format, keeping its comments"

        example [
          "                                  # the suite's .llm-evals.config.yml",
          "-C evals/.llm-evals.config.yml    # another lineup file",
          "-n                                # print the result, change nothing"
        ]

        option :config, aliases: ["-C"], desc: "The lineup file (default: the suite's .llm-evals.config.yml)"
        option :dry_run, type: :boolean, default: false, aliases: ["-n"], desc: "Print the result, change nothing"

        def call(config: nil, dry_run: false, **)
          path = config ? File.expand_path(config) : configuration.lineup.path
          raise Error, "no config file at #{path}" unless File.exist?(path)

          text = File.read(path)
          upgrade = ConfigUpgrade.new(text)
          return status_box(:info, "#{path} is already in the current format") unless upgrade.needed?

          upgraded = upgrade.call
          return out.write(upgraded) if dry_run

          backup = "#{path}.bak"
          raise Error, "#{backup} already exists; move it away first" if File.exist?(backup)

          File.write(backup, text)
          File.write(path, upgraded)
          status_box(:success, "#{path} upgraded; the old file is #{backup}")
        end
      end
    end
  end
end
