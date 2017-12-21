class UserMailer < ApplicationMailer
  default from: "d2rq-mapper@dbcls.rois.ac.jp"

  def password_reset(user)
    @user = user
    mail to: user.email, subject: "[D2RQ Mapper] Please reset your password"
  end
  
end
