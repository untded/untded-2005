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
      write_html(elements)
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
        csv << %w[tag change_tag status name name_fr description repr_raw repr_charset
                  repr_min_length repr_max_length old_name business_term notes bridges
                  code_list page]
        elements.each do |e|
          csv << [
            e.tag, e.change_tag, e.status, e.name, e.name_fr, e.description,
            e.representation&.raw, e.representation&.charset,
            e.representation&.min_length, e.representation&.max_length,
            e.old_name, e.business_term, e.notes, e.bridges,
            e.code_list&.reference,
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

    def write_html(elements)
      rows = elements.map do |e|
        "<tr><td>#{e.tag}</td><td>#{esc(e.change_tag)}</td><td>#{esc(e.status)}</td>" \
          "<td>#{esc(e.name)}</td><td>#{esc(e.description)}</td><td>#{esc(e.representation&.raw)}</td>" \
          "<td>#{e.provenance.page}</td></tr>"
      end.join("\n")
      html = <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>UNTDED 2005 — data elements</title>
        <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; }
        table { border-collapse: collapse; width: 100%; font-size: 0.85rem; }
        th, td { border: 1px solid #ccc; padding: 0.25rem 0.5rem; text-align: left; vertical-align: top; }
        th { background: #f0f0f0; position: sticky; top: 0; }
        td:nth-child(1) { font-variant-numeric: tabular-nums; }
        </style>
        </head>
        <body>
        <h1>UNTDED 2005 — data elements</h1>
        <p>#{elements.size} elements, generated from the YAML SSOT in <code>data/elements/</code>.</p>
        <table>
        <thead><tr><th>Tag</th><th>Change</th><th>Status</th><th>Name</th><th>Description</th><th>Repr</th><th>Page</th></tr></thead>
        <tbody>
        #{rows}
        </tbody>
        </table>
        </body>
        </html>
      HTML
      File.write(File.join(@out_dir, "index.html"), html)
    end

    def esc(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
