# frozen_string_literal: true

module LLM
  module Evals
    module Datasets
      # Finds the cases under a root with a glob and decodes each path into a
      # {Case}. The default layout is
      #
      #   datasets/<dataset>/cases/<variant>/[NNN/]input.txt
      #   datasets/<dataset>/cases/<variant>/[NNN/]expected.json
      #
      # The folder after `datasets/` is the dataset, the folder holding the
      # input is the variant, unless it is a number, in which case it is the
      # case number and its parent is the variant.
      class Discovery
        # File holding a case's expected answer, beside its input.
        EXPECTED = "expected.json"
        # Optional file of extra case metadata, beside its input.
        METADATA = "metadata.json"

        # Where to look: `root` is absolute and `glob` is relative to it.
        #
        # @return [String]
        attr_reader :root, :glob

        # Reads nothing yet; {#all} does that, once.
        #
        # @param root [String] an absolute directory
        # @param glob [String] relative to root
        def initialize(root:, glob: Runtime::Configuration::DEFAULT_GLOB)
          @root = root
          @glob = glob
        end

        # Derived from the cases found, so a folder with no input file does not count.
        #
        # @return [Array<String>] every dataset that has at least one case, sorted
        def datasets = all.map(&:dataset).uniq.sort

        # {#cases}, for a caller that cannot go on without any.
        #
        # @param dataset [String]
        # @param only [Array<String>, nil] case id prefixes
        # @return [Array<Case>]
        # @raise [Error] when nothing matches
        def cases!(dataset:, only: [])
          cases(dataset:, only: Array(only)).tap do |found|
            raise Error, "no cases match #{Array(only).join(", ")} in #{dataset}" if found.empty?
          end
        end

        # A filtered view of {#all}. Entries of `only` may themselves be comma-separated,
        # and each matches the start of a case's id or its "dataset/id" key.
        #
        # @param dataset [String, nil] one dataset; nil for all of them
        # @param only [Array<String>] id prefixes to keep ("clear", "clear/00"); empty keeps all
        # @return [Array<Case>] sorted by dataset, variant and number
        # @raise [Error] when the dataset does not exist
        # @example
        #   discovery.cases(dataset: "colors", only: ["clear/00"]).map(&:key)
        #   # => ["colors/clear/001", "colors/clear/002"]
        def cases(dataset: nil, only: [])
          found = all
          if dataset
            raise Error, "no dataset #{dataset.inspect}; have #{datasets.join(", ")}" unless datasets.include?(dataset)

            found = found.select { it.dataset == dataset }
          end
          only = only.flat_map { it.split(",") }.map(&:strip).reject(&:empty?)
          found = found.select { |kase| only.any? { kase.id.start_with?(it) || kase.key.start_with?(it) } } unless only.empty?
          found
        end

        # Every case under the root, read on the first call and kept for this instance's life.
        #
        # @return [Array<Case>]
        # @raise [JSON::ParserError] when a case's metadata.json is malformed
        def all
          @all ||= Dir[File.join(root, glob)].map { decode(it) }
        end

        # Builds the case at one input file.
        #
        # @param input_path [String]
        # @return [Case]
        # @raise [JSON::ParserError] when the case's metadata.json is malformed
        def decode(input_path)
          dir = File.dirname(input_path)
          parts = Pathname(dir).relative_path_from(Pathname(root)).each_filename.to_a
          number = parts.last.match?(/\A\d+\z/) ? parts.last : nil
          variant = number ? parts[-2] : parts.last
          expected, problem = read_expected(File.join(dir, EXPECTED))
          Case.new(
            id:       [variant, number].compact.join("/"),
            dataset:  dataset_of(parts),
            variant:  variant,
            input:    File.read(input_path).strip,
            expected: expected,
            path:     dir,
            metadata: metadata(dir, number, problem)
          )
        end

        private

        # The folder after `datasets/`, else the first folder, so a glob that
        # does not say `datasets` still groups by its top level.
        #
        # @param parts [Array<String>] the case directory's path segments, relative to root
        # @return [String] the dataset's name
        def dataset_of(parts)
          index = parts.index("datasets")
          index && parts[index + 1] ? parts[index + 1] : parts.first
        end

        # Reports a missing or malformed file as a problem instead of raising, so the
        # case still loads and {Actions::Verify} can name what is wrong with it.
        #
        # @param path [String] where the case's expected.json should be
        # @return [Array(Object, nil), Array(nil, String)] the parsed answer and nil, or nil and the problem
        def read_expected(path)
          return [nil, "#{EXPECTED} is missing"] unless File.exist?(path)

          [JSON.parse(File.read(path)), nil]
        rescue JSON::ParserError => e
          [nil, "#{EXPECTED} is not valid JSON: #{e.message.lines.first&.strip}"]
        end

        # Derives the number and difficulty, then lets metadata.json override them.
        #
        # @param dir [String] the case's directory
        # @param number [String, nil] the NNN/ folder name, when the case has one
        # @param problem [String, nil] what is wrong with expected.json, kept as `expected_error`
        # @return [Hash{Symbol => Object}]
        # @raise [JSON::ParserError] when metadata.json is malformed; unlike expected.json, not caught here
        def metadata(dir, number, problem)
          extra = File.exist?(File.join(dir, METADATA)) ? JSON.parse(File.read(File.join(dir, METADATA))).transform_keys(&:to_sym) : {}
          { number: number&.to_i, difficulty: number.to_i, expected_error: problem }.compact.merge(extra)
        end
      end
    end
  end
end
