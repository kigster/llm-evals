# frozen_string_literal: true

module LLM
  module Evals
    class Config
      # The `results:` section: where completed runs are saved and how they are
      # presented. Paths are rooted at the caller's working directory, so the same
      # config works from a project root or when invoked by a task runner.
      Results = Data.define(:autosave, :destination, :temp_dir, :display_mode) do
        # @param section [Object] the section as the file has it
        # @param path [String] names the file in an error
        # @return [Results]
        # @raise [Error] when a setting has the wrong type or an unknown display
        def self.from_hash(section, path:)
          raise Error, "#{path}: results must be a mapping" unless section.is_a?(Hash)

          autosave = section.fetch("autosave", true)
          raise Error, "#{path}: results.autosave must be true or false" unless [true, false].include?(autosave)

          display = section.fetch("display", "tui").to_s
          raise Error, "#{path}: results.display must be one of #{RESULT_DISPLAYS.join(", ")}" unless RESULT_DISPLAYS.include?(display)

          new(autosave:,
            destination:  File.expand_path(section.fetch("destination", "./evals/results").to_s, Dir.pwd),
            temp_dir:     File.expand_path(section.fetch("temp_dir", "./tmp").to_s, Dir.pwd),
            display_mode: display)
        end
      end
    end
  end
end
