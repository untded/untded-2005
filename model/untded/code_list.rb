module Untded
  class CodeList < Lutaml::Model::Serializable
    attribute :reference, :string
    restrict :reference, required: true

    yaml do
      map :reference, to: :reference
    end
  end
end
