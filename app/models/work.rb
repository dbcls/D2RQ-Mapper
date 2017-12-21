class Work < ApplicationRecord

  has_many :db_connections, dependent: :destroy
  has_many :namespace_settings, dependent: :destroy
  has_many :class_maps, dependent: :destroy
  has_many :property_bridges, dependent: :destroy
  has_many :table_joins, dependent: :destroy

  validates :name, presence: true

  scope :for_menu, ->(user_id) {
    where(user_id: user_id).order(id: :desc)
  }


  def db_connection
    DbConnection.where(work_id: self.id).first
  end


  def table_exists?(table_name)
    db = TogoMapper::DB.new(db_connection.connection_config)
    db.tables.include?(table_name)
  end


  def has_license?
    !license_id.nil? && license_id > 0
  end
  
end
