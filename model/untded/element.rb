module Untded
  class Element < Lutaml::Model::Serializable
    attribute :tag, :integer
    restrict :tag, required: true
    attribute :name, :string
    attribute :name_fr, :string
    attribute :description, :string
    attribute :representation, Representation
    attribute :change_tag, :string
    restrict :change_tag, values: %w[add cnd cndr cnr cdr cn cr cd u x]
    attribute :status, :string
    restrict :status, values: %w[active retired]
    attribute :old_name, :string
    attribute :business_term, :string
    attribute :notes, :string
    attribute :bridges, :string
    attribute :code_list, CodeList
    attribute :provenance, Provenance
    restrict :provenance, required: true

    yaml do
      map :tag, to: :tag
      map :name, to: :name
      map :name_fr, to: :name_fr
      map :description, to: :description
      map :representation, to: :representation
      map :change_tag, to: :change_tag
      map :status, to: :status
      map :old_name, to: :old_name
      map :business_term, to: :business_term
      map :notes, to: :notes
      map :bridges, to: :bridges
      map :code_list, to: :code_list
      map :provenance, to: :provenance
    end
  end
end
