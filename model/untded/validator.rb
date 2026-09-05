module Untded
  class Validator
    Result = Struct.new(:errors, :summary, keyword_init: true)

    def initialize(data_dir)
      @data_dir = data_dir
    end

    def call
      errors = []
      elements = []
      files = Dir.glob(File.join(@data_dir, "elements", "*.yaml")).sort
      errors << "no element files found under #{@data_dir}/elements" if files.empty?

      files.each do |path|
        range = File.basename(path, ".yaml")
        base = range[0, 4].to_i
        file = ElementFile.from_yaml(File.read(path))
        file.elements.each do |el|
          begin
            el.validate!
          rescue Lutaml::Model::ValidationError => e
            errors << "#{range} tag #{el.tag}: #{e.message}"
          end
          unless el.tag.between?(base, base + 699)
            errors << "#{range}: tag #{el.tag} outside file range"
          end
        end
        elements.concat(file.elements)
      end

      duplicates = elements.map(&:tag).tally.select { |_, v| v > 1 }
      duplicates.each { |tag, n| errors << "tag #{tag} appears #{n} times" }

      missing_name = elements.count { |e| e.name.nil? && e.status == "active" }
      missing_repr = elements.count { |e| e.representation.nil? && e.status == "active" }

      queue_path = File.join(@data_dir, "review-queue.yaml")
      queue_entries = 0
      if File.file?(queue_path)
        queue = ReviewQueue.from_yaml(File.read(queue_path))
        queue_entries = queue.entries.to_a.size
      else
        errors << "missing review-queue.yaml"
      end

      summary = {
        files: files.size,
        elements: elements.size,
        active: elements.count { |e| e.status == "active" },
        retired: elements.count { |e| e.status == "retired" },
        active_without_name: missing_name,
        active_without_repr: missing_repr,
        review_entries: queue_entries,
        confidence: elements.map { |e| e.provenance.confidence }.tally,
      }
      Result.new(errors: errors, summary: summary)
    end
  end
end
