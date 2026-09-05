module Untded
  class ReviewQueue < Lutaml::Model::Serializable
    attribute :entries, ReviewEntry, collection: true

    yaml do
      map :entries, to: :entries
    end
  end
end
