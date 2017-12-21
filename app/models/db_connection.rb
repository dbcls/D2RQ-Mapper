class DbConnection < ApplicationRecord

  belongs_to :work

  before_save :encrypt_password

  validates :adapter, presence: true
  validates :host, presence: { unless: "adapter == 'sqlite3'" }
  validates :port, numericality: { only_integer: true, unless: "adapter == 'sqlite3'" }
  validates :database, presence: true
  validates :username, presence: { unless: "adapter == 'sqlite3'" }

  
  def encrypt_password
    self.password = encrypt(self.password)
  end

  
  def encrypt(password)
    crypt = ActiveSupport::MessageEncryptor.new(SECURE, cipher: CIPHER)
    crypt.encrypt_and_sign(password)
  end

  
  def decrypt(password)
    crypt = ActiveSupport::MessageEncryptor.new(SECURE, cipher: CIPHER)
    crypt.decrypt_and_verify(password)
  end

  
  def decrypt_password
    decrypt(self.password)
  end


  def connection_config
    {
      adapter: self.adapter,
      host: self.host,
      port: self.port,
      database: self.database,
      username: self.username,
      password: self.decrypt_password
    }
  end

end
