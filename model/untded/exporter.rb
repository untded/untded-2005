require "csv"
require "json"

module Untded
  class Exporter
    def initialize(data_dir, out_dir)
      @data_dir = data_dir
      @out_dir = out_dir
    end

    def call
      require "fileutils"
      FileUtils.mkdir_p(@out_dir)
      elements = load_elements
      write_csv(elements)
      write_json(elements)
      write_categories
      write_vocabulary
      write_context
      elements.size
    end

    private

    def load_elements
      Dir.glob(File.join(@data_dir, "elements", "*.yaml")).sort.flat_map do |path|
        ElementFile.from_yaml(File.read(path)).elements
      end.sort_by(&:tag)
    end

    def write_csv(elements)
      CSV.open(File.join(@out_dir, "elements.csv"), "w") do |csv|
        csv << %w[tag change_tag status name description repr_raw repr_charset
                  repr_min_length repr_max_length old_name business_term notes bridges
                  page]
        elements.each do |e|
          csv << [
            e.tag, e.change_tag, e.status, e.name, e.description,
            e.representation&.raw, e.representation&.charset,
            e.representation&.min_length, e.representation&.max_length,
            e.old_name, e.business_term, e.notes, e.bridges,
            e.provenance.page,
          ]
        end
      end
    end

    def write_json(elements)
      doc = {
        "source" => "UNTDED 2005 (United Nations Trade Data Elements Directory, ECE/TRADE/362)",
        "pages" => "28-132",
        "element_count" => elements.size,
        "elements" => elements.map(&:to_hash),
      }
      File.write(File.join(@out_dir, "elements.json"), JSON.pretty_generate(doc))
    end

    # The nine tag-range categories as structured records; consumed by
    # the website via sync-data (single category writer).
    def write_categories
      File.write(File.join(@out_dir, "categories.json"),
        JSON.pretty_generate(Untded::Categories::ALL))
    end

    # Regenerates the committed YAML-LD context from the vocabulary
    # declaration — the file is derived output, never hand-edited.
    def write_context(target: File.expand_path("../../vocab/untded-context.yamlld", __dir__))
      groups = Vocabulary::TERMS.group_by { |_, defn| defn[:group] }
      order = ["classes", "dataset-level", "element-level", "category-level", "vocabulary definitions"]
      lines = [
        "# YAML-LD context — GENERATED from model/untded/vocabulary.rb by",
        "# bin/export. Do not edit; change the declaration instead.",
        "\"@context\":",
      ]
      Vocabulary::PREFIXES.each { |prefix, iri| lines << "  #{prefix}: #{iri}" }
      order.each do |group|
        lines << ""
        lines << "  # #{group}"
        (groups[group] || []).each { |term, defn| lines << "  #{term}: #{defn[:iri]}" }
      end
      File.write(target, lines.join("\n") + "\n")
    end


    # The vocabulary declaration as JSON: namespace, prefixes, classes
    # and terms — consumed by the website's /ontology page (single
    # writer; mirrors the committed context).
    def write_vocabulary
      doc = {
        "namespace" => Vocabulary::NAMESPACE,
        "prefixes" => Vocabulary::PREFIXES,
        "classes" => Vocabulary::CLASSES.map { |name, comment| { "term" => name, "comment" => comment } },
        "terms" => Vocabulary::TERMS.filter_map do |term, defn|
          next if defn[:group] == "classes"
          { "term" => term, "iri" => defn[:iri], "group" => defn[:group] }
            .merge(defn[:domain] ? { "domain" => defn[:domain] } : {})
            .merge(defn[:comment] ? { "comment" => defn[:comment] } : {})
        end,
      }
      File.write(File.join(@out_dir, "vocabulary.json"), JSON.pretty_generate(doc))
    end
  end
end
