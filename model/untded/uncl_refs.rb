require "set"
module Untded
  # Section-4.1.5 cross-references from the full-text UNCL (D.01B
  # simples, mirrored in references/edifact-D01B/uncl/). A qualifier
  # code whose combined meaning equals a TDED element carries that
  # element's tag in [square brackets] at the start of its description
  # (rule 1.3); related TDED tags appear in (parentheses) (rule 1.4 and
  # narrative). Vintage: D.01B — one release before the edition's D.02A;
  # labeled as such everywhere. The short-names-only D05B codes.xml is
  # coverage (UnclCoverage); this is the deep join.
  module UnclRefs
    CODE_START = /\A\s{0,6}([A-Z0-9]{1,3})\s{2,}(\S.*)\z/
    CONTINUATION = /\A\s{10,}(\S.*)\z/
    BRACKET = /\[(\d{4})\]/
    PAREN = /\((\d{4})\)/

    Ref = Struct.new(:code_list, :code, :name, :description, :kind, :tag, keyword_init: true)

    def self.parse_file(path)
      list = File.basename(path, ".txt").to_i
      return [] unless list >= 1000

      refs = []
      current = nil
      File.foreach(path) do |raw|
        line = raw.rstrip
        next if line.empty? || line.start_with?("*") || line.match?(/\A\s*(Desc|Repr|Note):/i)

        if (m = line.match(CODE_START))
          flush = current
          refs.concat(extract(flush)) if flush
          current = { code_list: list, code: m[1], name: m[2].strip, desc_parts: [] }
        elsif current && (m = line.match(CONTINUATION))
          current[:desc_parts] << m[1].strip
        end
      end
      refs.concat(extract(current)) if current
      refs
    end

    def self.extract(entry)
      return [] unless entry
      description = entry[:desc_parts].join(" ").strip
      text = "#{entry[:name]} #{description}"
      out = []
      # rule 1.3: [nnnn] at the start of the description (or of the name
      # when the description is empty) — the primary cross-reference
      if (m = description.match(/\A\[(\d{4})\]/) || entry[:name].match(/\A\[(\d{4})\]/))
        out << Ref.new(
          code_list: entry[:code_list], code: entry[:code], name: entry[:name],
          description: description, kind: "equals", tag: m[1].to_i,
        )
      end
      # remaining [nnnn] and (nnnn) anywhere — related references
      seen = out.map(&:tag).to_set
      text.scan(BRACKET).flatten.map(&:to_i).each do |tag|
        next if seen.include?(tag)
        seen << tag
        out << Ref.new(
          code_list: entry[:code_list], code: entry[:code], name: entry[:name],
          description: description, kind: "related", tag: tag,
        )
      end
      text.scan(PAREN).flatten.map(&:to_i).each do |tag|
        next if seen.include?(tag)
        next unless tag >= 1000 # service elements and years stay out
        seen << tag
        out << Ref.new(
          code_list: entry[:code_list], code: entry[:code], name: entry[:name],
          description: description, kind: "related", tag: tag,
        )
      end
      out
    end

    def self.parse_dir(dir)
      Dir.glob(File.join(dir, "*.txt")).sort.flat_map { |p| parse_file(p) }
    end

    # Group by the referenced TDED tag; keep only tags that exist in the
    # directory. Unknown tags are returned separately for the review queue.
    def self.links(elements, refs)
      tags = elements.map(&:tag).to_set
      known, unknown = refs.partition { |r| tags.include?(r.tag) }
      by_tag = known.group_by(&:tag).transform_values do |rs|
        rs.map { |r|
          {
            "code_list" => r.code_list,
            "code" => r.code,
            "name" => r.name,
            "kind" => r.kind,
            "description" => r.description.empty? ? nil : r.description,
          }
        }
      end
      {
        "links" => by_tag.sort.map { |tag, entries| { "tag" => tag, "refs" => entries } },
        "unknown_tags" => unknown.map(&:tag).uniq.sort,
      }
    end
  end
end
