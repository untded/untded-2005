module Untded
  class Provenance < Lutaml::Model::Serializable
    attribute :pdf, :string
    restrict :pdf, required: true
    attribute :page, :integer
    restrict :page, required: true
    attribute :confidence, :string
    restrict :confidence, values: %w[high medium low]

    yaml do
      map :pdf, to: :pdf
      map :page, to: :page
      map :confidence, to: :confidence
    end
  end
end
