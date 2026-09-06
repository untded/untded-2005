module Untded
  # Tag join of the directory against the UN/EDIFACT D.05B segments
  # mirror (references/edifact-D05B/segments.xml — a mirror of the
  # official UNECE publication, unece.org/trade/uncefact/unedifact,
  # listing every data element used in segments with name, description,
  # type and max length). The mirror covers only elements referenced by
  # segments; absence from it is informational, not a mismatch.
  module EdifactJoin
    MirrorEntry = Struct.new(:tag, :name, :desc, :type, :max_length, keyword_init: true)

    def self.mirror(xml_path)
      require "rexml/document"
      mirror = {}
      doc = REXML::Document.new(File.read(xml_path))
      REXML::XPath.match(doc, "//data_element").each do |el|
        id = el.attributes["id"].to_i
        next unless id >= 1000
        # first occurrence wins; later ones are repetitions in other segments
        mirror[id] ||= MirrorEntry.new(
          tag: id,
          name: el.attributes["name"],
          desc: el.attributes["desc"],
          type: el.attributes["type"],
          max_length: el.attributes["maxlength"].to_i,
        )
      end
      mirror
    end

    # One record per active element present in the mirror, with the two
    # printed representations side by side; aligned means the charset and
    # maximum length corroborate (the same rule bin/crosscheck-edifact
    # reports on).
    def self.links(elements, mirror)
      elements.select { |e| e.status == "active" && mirror.key?(e.tag) }.map do |e|
        m = mirror[e.tag]
        aligned = !e.representation.nil? && e.representation.charset == m.type &&
                  e.representation.max_length == m.max_length
        {
          "tag" => e.tag,
          "edifact" => { "name" => m.name, "type" => m.type, "maxLength" => m.max_length },
          "reprRaw" => e.representation&.raw,
          "aligned" => aligned,
        }
      end
    end
  end
end
