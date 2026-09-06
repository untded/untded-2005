module Untded
  class Provenance < Lutaml::Model::Serializable
    attribute :page, :integer
    restrict :page, required: true
    yaml do
      map :page, to: :page
    end
  end
end
