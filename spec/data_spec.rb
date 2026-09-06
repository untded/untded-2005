require "spec_helper"

RSpec.describe "YAML SSOT" do
  let(:files) { Dir.glob(File.join(data_dir, "elements", "*.yaml")).sort }
  let(:elements) do
    files.flat_map { |f| Untded::ElementFile.from_yaml(File.read(f)).elements }
  end
  let(:by_tag) { elements.to_h { |e| [e.tag, e] } }

  it "has one file per TDED tag-range category" do
    expect(files.map { |f| File.basename(f, ".yaml") }).to eq(
      %w[1000-1699 2000-2699 3000-3699 4000-4699 5000-5699 6000-6699 7000-7699 8000-8699 9000-9699]
    )
  end

  it "contains the full 2005 directory" do
    expect(elements.size).to eq(1504)
  end

  it "has unique tags" do
    expect(elements.map(&:tag).tally.select { |_, v| v > 1 }).to be_empty
  end

  it "round-trips known elements through the model" do
    expect(by_tag[1001].name).to eq("Document. Type.Code")
    expect(by_tag[1001].change_tag).to eq("cndr")
    expect(by_tag[2000].change_tag).to eq("u")
    expect(by_tag[2000].status).to eq("active")
    expect(by_tag[2000].old_name).to eq("Date")
    expect(by_tag[2000].name).to eq("Date. Date.Text")
    expect(by_tag[9649].name).to eq("Process. Information Function.Code")
  end

  it "attaches provenance to every element" do
    expect(elements.all? { |e| e.provenance.page.between?(28, 132) }).to be(true)
  end

  it "parses every present representation through the notation grammar" do
    elements.each do |e|
      next if e.representation.nil?
      expect(e.representation.charset).to match(/\A(a|an|n)\z/)
      expect(e.representation.max_length).to be >= e.representation.min_length
    end
  end

  it "loads the review queue through the model" do
    queue = Untded::ReviewQueue.from_yaml(File.read(File.join(data_dir, "review-queue.yaml")))
    expect(queue.entries.to_a).to be_an(Array)
  end

  it "queues the four change tags printed outside the section 4.1 legend" do
    queue = Untded::ReviewQueue.from_yaml(File.read(File.join(data_dir, "review-queue.yaml")))
    tags = queue.entries.map(&:tag)
    expect(tags).to contain_exactly(5082, 5180, 5390, 5450)
    expect(queue.entries.map { |e| e.raw_fragments.first }).to all(match(/\A[a-z]{2,3}\z/))
    expect(queue.entries.map(&:page)).to all(be_between(28, 132))
  end
end
