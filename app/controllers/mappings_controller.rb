class MappingsController < ApplicationController
  include TogoMapper::Namespace

  def index
    @works = Work.for_menu(current_user.id)
    if xhr?
      set_headers_for_cross_domain
      response_json
    else
    end
  end


  def namespaces
    @work = Work.find(params[:id])
    namespaces = namespaces_by_namespace_settings(@work.id)
    
    data = common_json_data('100')
    data[:namespaces] = []
    namespaces.each do |ns|
      data[:namespaces] << {
        prefix: ns[:prefix],
        uri: ns[:uri]
      }
    end

    if xhr?
      set_headers_for_cross_domain
      render_json(data)
    end
  end

  
  def tables
    @work = Work.find(params[:id])
    data = common_json_data('100')
    data[:tables] = []
    @work.class_maps.each do |class_map|
      table = {
        id: class_map.id,
        name: class_map.table_name,
        enable: class_map.enable,
        xpos: class_map.er_xpos,
        ypos: class_map.er_ypos,
        columns: []
      }
      class_map.property_bridges.each do |property_bridge|
        table[:columns] << {
          id: property_bridge.id,
          name: property_bridge.column_name,
          enable: property_bridge.enable
        }
      end
      data[:tables] << table
    end

    if xhr?
      set_headers_for_cross_domain
      render_json(data)
    end
  end

  
  def configure
    class_map = ClassMap.table_derived(params[:id]).select(&:enable)[0]

    redirect_to triples_map_url(class_map)
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
