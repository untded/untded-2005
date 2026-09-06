module Untded
  # Code-list coverage of the directory against the UN/EDIFACT D.05B
  # UNCL mirror (references/edifact-D05B/codes.xml — the user code list
  # of the official UNECE publication via the php-edifact mirror). The
  # mirror carries code values with short names only; the full
  # descriptions with the section-4.1.5 bracket cross-references are in
  # the official UNCL file and are not mirrored. Absence from the mirror
  # is informational, not a mismatch; ids that are not TDED elements
  # (service code elements etc.) are skipped.
  module UnclCoverage
    def self.counts(xml_path)
      require "rexml/document"
      counts = {}
      doc = REXML::Document.new(File.read(xml_path))
      REXML::XPath.match(doc, "/data_elements/data_element").each do |el|
        counts[el.attributes["id"].to_i] = REXML::XPath.match(el, "code").size
      end
      counts
    end

    def self.links(elements, counts)
      elements.select { |e| e.status == "active" && counts.key?(e.tag) }.map do |e|
        { "tag" => e.tag, "code_values" => counts.fetch(e.tag) }
      end
    end

    def self.skipped_ids(counts, tags)
      counts.keys.reject { |id| tags.include?(id) }
    end
  end
end
