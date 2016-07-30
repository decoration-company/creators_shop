class User < ActiveRecord::Base
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  has_secure_password
  mount_uploader :avatar, AvatarUploader

  has_many :identities, dependent: :destroy

  validates :name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX },
            uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, allow_nil: true

  before_create :create_remember_token
  before_save { self.email = email.downcase }

  class << self
    def create_with_omniauth(auth)
      auth['info']['email'] ||= dummy_email(auth)
      create(name: auth['info']['name'], email: auth['info']['email'], image_url: auth['info']['image'], password: friendly_token(20))

      # Facebook：activated:true
      # Twitter：activated:false
    end

    def new_remember_token
      SecureRandom.urlsafe_base64
    end

    def encrypt(token)
      Digest::SHA1.hexdigest(token.to_s)
    end

    def dummy_email(auth)
      "#{auth.uid}-#{auth.provider}@example.com"
    end
    private :dummy_email

    def friendly_token(length = 20)
      rlength = (length * 3) / 4
      SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
    end
    private :friendly_token
  end

  private

    def create_remember_token
      self.remember_token ||= User.encrypt(User.new_remember_token)
    end

end
