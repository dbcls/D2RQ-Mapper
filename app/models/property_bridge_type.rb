class PropertyBridgeType < ApplicationRecord
  scope :column, ->{ find_by(symbol: 'column') }
  scope :label, ->{ find_by(symbol: 'label') }
  scope :bnode, ->{ find_by(symbol: 'bnode') }
  scope :constant, ->{ find_by(symbol: 'constant') }
end
