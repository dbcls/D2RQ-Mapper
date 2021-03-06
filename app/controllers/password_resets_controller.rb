class PasswordResetsController < ApplicationController

  def new
  end


  def create
    user = User.find_by_email(params[:email])
    if user
      user.send_password_reset
      redirect_to new_password_reset_path, notice: "Check your email for a link to reset your password."
    else
      redirect_to new_password_reset_path, alert: "Can't find that email, sorry."
    end
  end


  def edit
    @user = User.find_by_password_reset_token!(params[:id])
  end


  def update
    @user = User.find_by_password_reset_token!(params[:id])
    if @user.password_reset_sent_at < 2.hours.ago
      redirect_to new_password_reset_path, alert: "Password reset has expired."
    elsif @user.update_attributes(user_params)
      redirect_to new_user_session_path, notice: "New password set successfully."
    else
      render :edit
    end
  end

  private

  def user_params
    params.require(:user).permit(:password)
  end

end
