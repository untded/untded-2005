require "spec_helper"

RSpec.describe Untded::Extractor do
  subject(:extractor) { described_class.new(pdf: source_pdf, pages: 28..30) }

  let(:elements) { extractor.extract[0] }
  let(:by_tag) { elements.to_h { |e| [e.tag, e] } }

  it "parses one element per printed row" do
    expect(elements.size).to eq(50)
  end

  it "captures the first line of every column" do
    e = by_tag[1000]
    expect(e.name).to eq("Document. Type Name.Text")
    expect(e.description).to start_with("Free text name of a document")
    expect(e.representation.raw).to eq("an..35")
    expect(e.bridges).to include("UNLK: L 02, P 45-80", "MAR: IMO/FAL 1-7")
  end

  it "reassembles OCR mid-word breaks in narrow columns" do
    expect(by_tag[1000].old_name).to eq("Document/message name")
    expect(by_tag[1001].old_name).to eq("Document/message name, coded")
    expect(by_tag[1001].business_term).to eq("Document/message name code")
    expect(by_tag[1066].old_name).to eq("Number of original Bills of Lading, in words")
  end

  it "marks retired elements and keeps their notes" do
    e = by_tag[1002]
    expect(e.change_tag).to eq("x")
    expect(e.status).to eq("retired")
    expect(e.name).to be_nil
    expect(e.notes).to eq("DE to use instead - 1000")
  end

  it "parses the representation notation" do
    expect(by_tag[1001].representation.to_hash).to include(
      "charset" => "an", "min_length" => 1, "max_length" => 3
    )
    expect(by_tag[1067].representation.raw).to eq("n..2")
    expect(by_tag[1070].representation.raw).to eq("an1")
  end

  it "records provenance with the PDF page" do
    expect(by_tag[1066].provenance.page).to eq(30)
    expect(by_tag[1000].provenance.pdf).to eq("UNTDED2005_Redacted.pdf")
  end
end
