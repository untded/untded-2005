module Untded
  class ReviewEntry < Lutaml::Model::Serializable
    attribute :page, :integer
    restrict :page, required: true
    attribute :tag, :integer
    attribute :field, :string
    restrict :field, required: true
    attribute :raw_fragments, :string, collection: true
    attribute :issue, :string
    restrict :issue, required: true
    attribute :confidence, :string
    restrict :confidence, values: %w[high medium low]

    yaml do
      map :page, to: :page
      map :tag, to: :tag
      map :field, to: :field
      map :raw_fragments, to: :raw_fragments
      map :issue, to: :issue
      map :confidence, to: :confidence
    end
  end
end
