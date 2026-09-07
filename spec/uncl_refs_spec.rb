require "spec_helper"

RSpec.describe Untded::UnclRefs do
  let(:mirror_dir) do
    File.join(ENV.fetch("UNTDED_REFERENCES_DIR", File.join(project_root, "..", "references")),
              "edifact-D01B", "uncl")
  end
  let(:elements) { Untded.elements_from(data_dir) }

  before { skip "D01B UNCL mirror not present" unless Dir.exist?(mirror_dir) }

  it "parses the publication's own rule-1.3 example: 3035 BB → [3420]" do
    refs = described_class.parse_file(File.join(mirror_dir, "3035.txt"))
    bb = refs.find { |r| r.code == "BB" && r.kind == "equals" }
    expect(bb).not_to be_nil
    expect(bb.tag).to eq(3420)
    expect(bb.name).to eq("Buyer's bank")
    expect(bb.description).to start_with("[3420]")
  end

  it "joins only tags that exist in TDED; unknown tags reported" do
    refs = described_class.parse_dir(mirror_dir)
    result = described_class.links(elements, refs)
    tags = elements.map(&:tag).to_set
    result["links"].each do |link|
      expect(tags).to include(link["tag"])
      expect(link["refs"]).not_to be_empty
      link["refs"].each { |r| expect(%w[equals related]).to include(r["kind"]) }
    end
    result["unknown_tags"].each { |t| expect(tags).not_to include(t) }
  end

  it "covers both equals and related kinds" do
    refs = described_class.parse_dir(mirror_dir)
    expect(refs.count { |r| r.kind == "equals" }).to be > 50
    expect(refs.count { |r| r.kind == "related" }).to be > 50
  end
end
