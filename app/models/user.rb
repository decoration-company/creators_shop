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

  def self.create_with_omniauth(auth)
    auth['info']['email'] ||= User.dummy_email(auth)
    create(name: auth['info']['name'], email: auth['info']['email'], image_url: auth['info']['image'], password: User.friendly_token(20))

    # Facebook：activated:true
    # Twitter：activated:false
  end

  def User.new_remember_token
    SecureRandom.urlsafe_base64
  end

  def User.encrypt(token)
    Digest::SHA1.hexdigest(token.to_s)
  end

  private

    def create_remember_token
      self.remember_token ||= User.encrypt(User.new_remember_token)
    end

    def self.dummy_email(auth)
      "#{auth.uid}-#{auth.provider}@example.com"
    end

    def self.friendly_token(length = 20)
      rlength = (length * 3) / 4
      SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
    end

end
