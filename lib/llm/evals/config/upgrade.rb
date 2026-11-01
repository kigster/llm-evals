# frozen_string_literal: true

require "yaml"

module LLM
  module Evals
    class Config
      # Rewrites a lineup from top-level `vendors:` and `direct:` to provider
      # sections. It works on the text, since loading YAML would drop the comments
      # that explain a lineup, then proves the result means the same before
      # anything is written.
      class Upgrade
        # A line that opens a new top-level key, which ends any section being moved.
        TOP_KEY = /\A[\w-]+:/
        # The old `vendors:` line, keeping whatever follows the colon.
        VENDORS = /\Avendors:(?<rest>.*)/m
        # The old `direct:` line, with at most a comment after it.
        DIRECT = /\Adirect:\s*(?<comment>#.*)?\n?\z/
        # A key indented by two spaces: a vendor, or a direct provider.
        GROUP = /\A  ([\w-]+):([^\n]*)\n?\z/

        # @param text [String] the lineup as it is
        # @param path [String] named in every error
        # @raise [Error] when the text is not YAML, or not a mapping
        def initialize(text, path:)
          @text = text
          @path = path
          @data = YAML.safe_load(text) || {}
          raise Error, "#{path}: a lineup must be a mapping, not a #{@data.class.name.downcase}" unless @data.is_a?(Hash)
        rescue Psych::SyntaxError => e
          raise Error, "#{path}: not valid YAML: #{e.message}"
        end

        # @return [Boolean] whether the lineup still has the old keys
        def needed? = @data.key?("vendors") || @data.key?("direct")

        # @return [String] the lineup in the new shape
        # @raise [Error] when the rewrite would change what the file means
        def call
          taken = [("openrouter" if @data.key?("vendors")), *(@data["direct"] || {}).keys].compact & @data.keys
          raise Error, "#{@path}: cannot upgrade: the file has both the old keys and a section named #{taken.join(", ")}" if taken.any?

          rewritten = rewrite
          return rewritten if same_meaning?(rewritten)

          raise Error, "#{@path}: cannot upgrade: vendors: or direct: is not in the plain list form; move them by hand"
        end

        private

        # The proof that a textual rewrite is safe to write.
        #
        # @param rewritten [String] the lineup in the new shape
        # @return [Boolean] whether it loads to what {#expected} says; false when it is not YAML
        def same_meaning?(rewritten)
          YAML.safe_load(rewritten) == expected
        rescue Psych::SyntaxError
          false
        end

        # Rewrites the text line by line, tracking which old section the line falls in.
        #
        # @return [String] the lineup in the new shape
        def rewrite
          section = nil
          @text.lines.flat_map do |line|
            section = nil if line.match?(TOP_KEY)
            if (vendors = VENDORS.match(line))
              section = :vendors
              ["openrouter:#{vendors[:rest]}", "  vendors:\n"]
            elsif (direct = DIRECT.match(line))
              section = :direct
              direct[:comment] ? ["#{direct[:comment]}\n"] : []
            else
              moved(section, line)
            end
          end.join
        end

        # Reindents one line of an old section; comments and blank lines stay as they are.
        #
        # @param section [Symbol, nil] `:vendors`, `:direct`, or nil outside both
        # @param line [String] the line, with its newline
        # @return [Array<String>] the line or lines that replace it
        def moved(section, line)
          return [line] if section.nil? || line.strip.empty? || line.start_with?("#")

          group = GROUP.match(line)
          case section
          when :vendors then group ? ["    #{group[1]}:#{group[2]}\n", "      models:\n"] : ["    #{line}"]
          else group ? ["#{group[1]}:#{group[2]}\n", "  models:\n"] : [line]
          end
        end

        # What the file means in the new shape, built from the parsed data rather than the text.
        #
        # @return [Hash{String => Object}] the lineup as {#same_meaning?} expects it to load
        def expected
          rest = @data.except("vendors", "direct")
          vendors = @data["vendors"]&.transform_values { { "models" => it } }
          direct = (@data["direct"] || {}).transform_values { { "models" => it } }
          rest.merge(vendors ? { "openrouter" => { "vendors" => vendors } } : {}).merge(direct)
        end
      end
    end
  end
end
