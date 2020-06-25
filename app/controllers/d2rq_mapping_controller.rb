require 'togo_mapper/d2rq/mapping_generator'

class D2rqMappingController < ApplicationController
  before_action :authenticate_user!, :set_html_body_class

  def show
    validate_user

    @work = Work.find(params[:id])
    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_work(@work)
    @mapping_data = mapping_generator.generate

    if xhr?
      set_headers_for_cross_domain
      response_json
    else
      respond_to do |format|
        format.html { render layout: 'graph' }
        format.ttl { render plain: @mapping_data, content_type: 'text/plain' }
      end
    end
  end


  def download
    validate_user

    @work = Work.find(params[:id])
    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_work(@work)

    send_data(
      mapping_generator.generate,
      filename: "#{@work.name}-d2rq-mapping.ttl", type: 'text/turtle'
    )
  end


  def by_table
    class_map = ClassMap.find(params[:id])
    @work = class_map.work
    validate_user(@work.id)
    
    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_class_map(class_map)
    @mapping_data = mapping_generator.generate_by_class_map

    if xhr?
      set_headers_for_cross_domain
      response_json
    else
      render plain: @mapping_data, content_type: 'text/plain'
    end
  end


  def by_column
    property_bridge = PropertyBridge.find(params[:id])
    @work = property_bridge.work
    validate_user(@work.id)
    
    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_property_bridge(property_bridge)
    @mapping_data = mapping_generator.generate_by_property_bridge

    if xhr?
      if json?
        set_headers_for_cross_domain
        response_json
      else
        response_js
      end
    else
      render plain: @mapping_data, content_type: 'text/plain'
    end
  end

  def by_table_join
    table_join = TableJoin.find(params[:id])
    @work = table_join.work
    validate_user(@work.id)
    
    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_table_join(table_join)
    @mapping_data = mapping_generator.generate_by_table_join

    render plain: @mapping_data, content_type: 'text/plain'
  end

  private

  def generate_d2rq_mapping
    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_work(@work.id)
  end

  
  def set_html_body_class
    @html_body_class = 'rdf page-get'
  end


  def response_json
    data = common_json_data('100')
    data[:d2rq_mapping] = @mapping_data

    render_json(data)
  end
  
end
