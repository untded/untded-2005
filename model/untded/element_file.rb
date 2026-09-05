module Untded
  class ElementFile < Lutaml::Model::Serializable
    attribute :category, :string
    restrict :category, required: true
    attribute :elements, Element, collection: true

    yaml do
      map :category, to: :category
      map :elements, to: :elements
    end
  end
end
