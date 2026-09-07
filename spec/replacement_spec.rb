require "spec_helper"

RSpec.describe Untded::Replacement do
  let(:elements) do
    Untded.elements_from(data_dir)
  end
  let(:tags) { elements.map(&:tag) }

  it "reads the printed pointer on a retired entry" do
    e = elements.find { |x| x.tag == 1002 }
    expect(e.notes).to eq("DE to use instead - 1000")
    expect(described_class.of(e, tags)).to eq(1000)
  end

  it "guards against years and unknown tags" do
    retired = elements.find { |x| x.status == "retired" }
    expect(described_class.of(retired, Set.new)).to be_nil
    year_note = Untded::Element.new(tag: 2000, status: "retired", change_tag: "x",
                                    notes: "see 2001 edition", provenance: Untded::Provenance.new(page: 1))
    expect(described_class.of(year_note, [2001])).to be_nil
  end

  it "returns nothing for active elements" do
    active = elements.find { |x| x.status == "active" }
    expect(described_class.of(active, tags)).to be_nil
  end
end
