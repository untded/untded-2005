module Untded
  class Representation < Lutaml::Model::Serializable
    attribute :raw, :string
    restrict :raw, required: true
    attribute :charset, :string
    restrict :charset, values: %w[a an n]
    attribute :min_length, :integer
    attribute :max_length, :integer

    yaml do
      map :raw, to: :raw
      map :charset, to: :charset
      map :min_length, to: :min_length
      map :max_length, to: :max_length
    end

    NOTATION = /\A(a|an|n)(?:\.\.(\d+)|(\d+))\z/.freeze

    def self.from_notation(raw)
      return nil if raw.nil?
      m = NOTATION.match(raw.strip)
      return nil unless m

      if m[2]
        min = 1
        max = m[2].to_i
      else
        min = max = m[3].to_i
      end
      new(raw: raw.strip, charset: m[1], min_length: min, max_length: max)
    end

    def fixed?
      min_length == max_length
    end
  end
end
