require "spec_helper"

RSpec.describe Untded::EdifactJoin do
  let(:elements) do
    Dir.glob(File.join(data_dir, "elements", "*.yaml")).sort.flat_map do |path|
      Untded::ElementFile.from_yaml(File.read(path)).elements
    end
  end
  let(:mirror_path) do
    File.join(ENV.fetch("UNTDED_REFERENCES_DIR", File.join(project_root, "..", "references")),
              "edifact-D05B", "segments.xml")
  end

  before do
    skip "D05B mirror not present" unless File.exist?(mirror_path)
  end

  it "joins on tag with the printed representations side by side" do
    links = described_class.links(elements, described_class.mirror(mirror_path))
    l1004 = links.find { |l| l["tag"] == 1004 }
    expect(l1004).to include("reprRaw" => "an..35", "aligned" => true)
    expect(l1004["edifact"]).to include("type" => "an", "maxLength" => 35)
  end

  it "marks representation differences honestly" do
    links = described_class.links(elements, described_class.mirror(mirror_path))
    expect(links.count { |l| !l["aligned"] }).to be_positive
    expect(links.size).to eq(586)
  end
end
