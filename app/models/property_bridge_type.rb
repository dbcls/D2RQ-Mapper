class PropertyBridgeType < ApplicationRecord
  scope :column, -> { where(symbol: 'column').first }
  scope :label, -> { where(symbol: 'label').first }
  scope :bnode, -> { where(symbol: 'bnode').first }
end
