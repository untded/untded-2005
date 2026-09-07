require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe "parser fixtures export" do
  it "writes one case per fixed sample tag, pinned to the YAML" do
    Dir.mktmpdir do |tmp|
      Untded::Exporter.new(data_dir, tmp).call
      doc = JSON.parse(File.read(File.join(tmp, "parser-fixtures.json")))
      tags = doc["cases"].map { |c| c["tag"] }
      expect(tags.sort).to eq(Untded::Exporter::FIXTURE_TAGS.sort)

      by = tags.to_h { |t| [t, doc["cases"].find { |c| c["tag"] == t }] }
      # the edge cases the ports must not diverge on
      expect(by[1082]["zones"]).to include(include("lineFrom" => 36, "posFrom" => 1, "posTo" => 8)) # zero-clamped P 00
      expect(by[5010]["bridges"]).to start_with("UNLK L 24") # colon-less scheme print
      expect(by[5010]["entries"]).to eq([{ "scheme" => "UNLK", "detail" => "L 24, P45-80" }])
      expect(by[2025]["zones"].size).to eq(2) # lowercase p tokens, two zones
      expect(by[1002]["replacement"]).to eq(1000)
    end
  end
end
