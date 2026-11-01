# frozen_string_literal: true

require "yaml"

module LLM
  module Evals
    # Rewrites a lineup from top-level `vendors:` and `direct:` to provider
    # sections. It works on the text, since loading YAML would drop the comments
    # that explain a lineup, then proves the result means the same before
    # anything is written.
    class ConfigUpgrade
      TOP_KEY = /\A[\w-]+:/
      VENDORS = /\Avendors:(?<rest>.*)/m
      DIRECT = /\Adirect:\s*(?<comment>#.*)?\n?\z/
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

      def same_meaning?(rewritten)
        YAML.safe_load(rewritten) == expected
      rescue Psych::SyntaxError
        false
      end

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

      def moved(section, line)
        return [line] if section.nil? || line.strip.empty? || line.start_with?("#")

        group = GROUP.match(line)
        case section
        when :vendors then group ? ["    #{group[1]}:#{group[2]}\n", "      models:\n"] : ["    #{line}"]
        else group ? ["#{group[1]}:#{group[2]}\n", "  models:\n"] : [line]
        end
      end

      def expected
        rest = @data.except("vendors", "direct")
        vendors = @data["vendors"]&.transform_values { { "models" => it } }
        direct = (@data["direct"] || {}).transform_values { { "models" => it } }
        rest.merge(vendors ? { "openrouter" => { "vendors" => vendors } } : {}).merge(direct)
      end
    end
  end
end
