require "spec_helper"

RSpec.describe Untded, ".elements_from" do
  it "loads the whole corpus, file-sorted — 1504 elements, tags ascending" do
    elements = described_class.elements_from(data_dir)
    expect(elements.size).to eq(1504)
    expect(elements.first.tag).to eq(1000)
    # the YAML SSOT is tag-ordered (the print's two inversions were
    # normalized at extraction; verifier's tag_order check pins them to
    # the PDF), so the corpus loads ascending
    tags = elements.map(&:tag)
    expect(tags.each_cons(2).all? { |a, b| b > a }).to be(true)
  end
end
