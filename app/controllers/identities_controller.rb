class IdentitiesController < ApplicationController

  def create
    auth = request.env['omniauth.auth']
    # Find an identity here
    @identity = Identity.find_with_omniauth(auth)

    if @identity.nil?
      # If no identity was found, create a brand new one here
      @identity = Identity.create_with_omniauth(auth)
    end

    if signed_in?
      if @identity.user == current_user
        # User is signed in so they are trying to link an identity with their
        # account. But we found the identity and the user associated with it
        # is the current user. So the identity is already associated with
        # this user. So let's display an error message.
        flash[:danger] = t('msg.already_linked')
        redirect_to root_url
      else
        # The identity is not associated with the current_user so lets
        # associate the identity
        @identity.user = current_user
        @identity.save()
        flash[:success] = t('msg.linked_successfully')
        redirect_to root_url
      end
    else
      if @identity.user.present?
        # The identity we found had a user associated with it so let's
        # just log them in here
        sign_in @identity.user
        flash[:info] = t('msg.signed_in')
        redirect_to root_url
      else
        # No user associated with the identity so we need to create a new one
        user = User.create_with_omniauth(auth)
        user.identities << @identity
        sign_in user
        flash[:info] = t('msg.finished_registering')
        redirect_to root_url
      end
    end
  end

  def destroy
    provider = params[:provider]
    if current_user.identities.count == 1
      flash[:danger] = t('msg.cannot_remove_all_accounts')
      redirect_to :back
    else
      identity = Identity.find_by_provider_and_user_id(provider, current_user.id)
      identity.destroy
      flash[:success] = t('msg.unlinked_successfully')
      redirect_to :back
    end
  end

end
