class MenuController < ApplicationController
  before_action :authenticate_user!

  def index
    page

    respond_to do |format|
      format.html { render action: :show }
      format.js   { response_json }
      format.json { response_json }
    end
        
  end


  def show
    page
  end

  private

  def page
    if user_signed_in?
      if params[:id]
        validate_user
        @work = Work.find(params[:id])
        @class_maps = @work.class_maps
      else
        @work = nil
      end

      @html_body_class = 'page-menu'
      @works = Work.for_menu(current_user.id)
    else
      redirect_to root_url
    end
  end

  private

  def response_json
    data = common_json_data("100")
    data[:mappings] = []
    @works.each do |work|
      data[:mappings] << {
        id:   work.id,
        name: work.name,
        date: work.updated_at.strftime("%Y/%m/%d %H:%M")
      }
    end
    render_json(data)
  end
  
end
