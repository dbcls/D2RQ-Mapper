class DbConnection < ApplicationRecord

  belongs_to :work

  before_save :encrypt_password

  validates :adapter, presence: true
  validates :host, presence: { unless: -> { adapter == 'sqlite3' } }
  validates :port, numericality: { only_integer: true, unless: -> { adapter == 'sqlite3' } }
  validates :database, presence: true
  validates :username, presence: { unless: -> { adapter == 'sqlite3' } }

  
  def encrypt_password
    self.password = encrypt(self.password)
  end

  
  def encrypt(password)
    message_encryptor.encrypt_and_sign(password)
  end

  
  def decrypt(password)
    message_encryptor.decrypt_and_verify(password)
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

  private

  def message_encryptor
    cipher = Rails.application.secrets.enc_cipher
    key = Rails.application.secrets.enc_key
    if key.is_a?(Array)
      key = key.pack("H*")
    end
    ActiveSupport::MessageEncryptor.new(key, cipher: cipher)
  end

end
