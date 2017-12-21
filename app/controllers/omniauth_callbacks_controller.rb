class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  
  def facebook
    @user = User.find_for_facebook_oauth(request.env["omniauth.auth"], current_user)
 
    if @user.persisted?
      flash.notice = "Login successful"
      sign_in_and_redirect @user, :event => :authentication
    else
      session["devise.facebook_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end


  def twitter
    user = User.find_for_twitter_oauth(request.env["omniauth.auth"], current_user)

    if user.persisted?
      flash.notice = "Login successful"
      sign_in_and_redirect user
    else
      session["devise.user_attributes"] = user.attributes
      redirect_to new_user_registration_url
    end
  end

  private

  def callback_from(provider)
    provider = provider.to_s

    @user = User.find_for_oauth(request.env['omniauth.auth'])

    if @user.persisted?
      flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: provider.capitalize)
      sign_in_and_redirect @user, event: :authentication
    else
      session["devise.#{provider}_data"] = request.env['omniauth.auth']
      redirect_to new_user_registration_url
    end
  end


  def user_params
    params.require(:user).permit(:email, :encrypted_password, :username, :provider, :uid)
  end
  
end
