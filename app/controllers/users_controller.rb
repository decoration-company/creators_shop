class UsersController < ApplicationController
  before_action :signed_in_user, only: [:edit, :billing, :update]

  def show
    @user = User.find(params[:id])
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      sign_in @user
      flash[:info] = t('msg.welcome')
      redirect_to @user
    else
      render 'new'
    end
  end

  def edit
    @user = User.find(current_user.id)
  end

  def update
    @user = User.find(current_user.id)
    if @user.update_attributes(user_params)
      flash[:success] = t('msg.updated_successfully')
      redirect_to @user
    else
      render 'edit'
    end
  end

  def billing
    @user = User.find(current_user.id)
  end

  def finish_signup
    @user = User.find(current_user)
  end

  def social
    @user = User.find(current_user.id)
    @providers = @user.identities.pluck(:provider)
  end

  private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation, :avatar, :remove_avatar)
    end

    def signed_in_user
      unless signed_in?
        store_location
        flash[:danger] = t('msg.please_signin')
        redirect_to signin_url
      end
    end
end