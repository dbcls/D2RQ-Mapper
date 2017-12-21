class IndexController < ApplicationController

  def welcome
    if user_signed_in?
      @works = Work.for_menu(current_user.id)
      redirect_to menu_index_url
    else
      # To do nothing, rendered index/welcome
    end
  end

end
