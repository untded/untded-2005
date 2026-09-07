require "spec_helper"

RSpec.describe Untded::Validator do
  it "validates the real YAML corpus with zero errors and correct summary" do
    result = described_class.new(data_dir).call
    expect(result.errors).to eq([])
    expect(result.summary[:files]).to eq(9)
    expect(result.summary[:elements]).to eq(1504)
    expect(result.summary[:active]).to eq(1318)
    expect(result.summary[:retired]).to eq(186)
    expect(result.summary[:active_without_name]).to eq(0)
    expect(result.summary[:active_without_repr]).to eq(4)
    expect(result.summary[:review_entries]).to eq(4)
  end
end
