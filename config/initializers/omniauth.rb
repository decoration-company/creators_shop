Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter,
    Rails.application.secrets.twitter_api_key,
    Rails.application.secrets.twitter_api_secret,
      {
        :secure_image_url => 'true',
        :image_size => 'original'
      }
  provider :facebook,
    Rails.application.secrets.facebook_api_key,
    Rails.application.secrets.facebook_api_secret,
      {
        :secure_image_url => 'true',
        :image_size => 'large'
      }
end