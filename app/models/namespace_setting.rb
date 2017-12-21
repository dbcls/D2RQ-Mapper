class NamespaceSetting < ApplicationRecord

  default_scope { order(id: :asc) }

  belongs_to :work
  belongs_to :namespace

end
