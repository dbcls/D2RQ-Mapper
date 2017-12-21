class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable,
         :omniauthable, omniauth_providers: [:twitter, :facebook]

  validates :username, presence: true, uniqueness: true

  class << self

    def new_with_session(params, session)
      if session["devise.user_attributes"]
        new(session["devise.user_attributes"], without_protection: true) do |user|
        user.attributes = params
          user.valid?
        end
      else
        super
      end
    end


    def find_for_facebook_oauth(auth, signed_in_resource = nil)
      user = User.where(provider: auth.provider, uid: auth.uid).first
      unless user
        user = User.create(username: auth.extra.raw_info.name,
                           provider: auth.provider,
                           uid:      auth.uid,
                           email:    auth.info.email,
                           password: Devise.friendly_token[0,20])
      end

      user
    end


    def find_for_twitter_oauth(auth, signed_in_resource = nil)
      user = User.where(provider: auth.provider, uid: auth.uid).first
      unless user
        user = User.create(username: auth.info.nickname,
                           provider: auth.provider,
                           uid:      auth.uid,
                           email:    User.create_unique_email,
                           password: Devise.friendly_token[0,20])
      end

      user
    end


    def from_omniauth(auth)
      where(auth.slice(:provider, :uid)).first_or_create do |user|
        user.username = auth.info.nickname
        user.email = auth.info.email
      end
    end


    def create_unique_string
      SecureRandom.uuid
    end
 

    def create_unique_email
      User.create_unique_string + "@example.com"
    end

  end


  def generate_token(column)
    begin
      self[column] = SecureRandom.urlsafe_base64
    end while User.exists?(column => self[column])
  end


  def password_required?
    super && provider.blank?
  end


  def update_with_password(params, *options)
    if encrypted_password.blank?
      update_attributes(params, *options)
    else
      super
    end
  end

  def send_password_reset
    generate_token(:password_reset_token)
    self.password_reset_sent_at = Time.zone.now
    save!  UserMailer.password_reset(self).deliver
  end

end
