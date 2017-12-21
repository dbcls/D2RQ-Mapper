class Namespace < ApplicationRecord

  default_scope { order(id: :asc) }
  scope :default_ns, -> { where(is_default: true) }

  has_many :namespace_settings

end
