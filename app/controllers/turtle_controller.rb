require 'tempfile'
require 'open3'
require 'togo_mapper/d2rq/mapping_generator'
require 'togo_mapper/d2rq/turtle_generator_job'

class TurtleController < ApplicationController
  before_action :authenticate_user!
  before_action :set_html_body_class, only: [ 'show' ]
  before_action :set_work, except: [ 'by_table', 'by_column', 'by_table_join' ]

  def show
    validate_user

    @turtle_exist = File.exist?(turtle_file_path)
    @generation_runninig = TurtleGeneration.exists?(work_id: @work.id, status: 'RUNNING')
    @turtle_is_latest = latest_turtle_file?

    render layout: 'graph'
  end


  def generate
    @turtle_exist = File.exist?(turtle_file_path)

    generation = TurtleGeneration.create!(
        work_id: @work.id,
        status: 'WAITING'
    )
    Resque.enqueue(TogoMapper::D2RQ::TurtleGeneratorJob,
                   @work.id,
                   "#{Rails.root}/data/turtle", "#{Rails.root}/data/tmp", generation.id)
  end


  def generation_status
    generation = TurtleGeneration.where(work_id: @work.id).order('id desc').first
    if generation
      render json: JSON.generate({ status: generation.status })
    else
      render json: JSON.generate({ status: 'NO GENERATION' })
    end
  end


  def refresh_button_area
    @turtle_exist = File.exist?(turtle_file_path)
    @turtle_is_latest = latest_turtle_file?
    @first_turtle_generation = TurtleGeneration.where(work_id: @work.id, status: 'SUCCESS').count < 2

    respond_to do |format|
      format.js
    end
  end


  def download
    validate_user

    unless params.key?("nosse")
      path = turtle_file_path
      if File.exist?(path)
        response.headers['Content-Length'] = File.size(path).to_s
        mode = "download"
        send_file(path,
                  filename: ERB::Util.url_encode("#{@work.name}.ttl"),
                  type: 'text/turtle',
                  length: File.size(path),
                  stream: true,
                  x_sendfile: true)
        return
      end
    end
    
    db_conn = DbConnection.where(work_id: @work.id).first

    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_work(@work)
    mapping_generator.password = db_conn.decrypt_password

    if params.key?("sse") || params.key?("nosse")
      mapping_generator.database_property = {
        'resultSizeLimit' => 5
      }
      mapping_generator.configuration_property = {
        'serveVocabulary' => false
      }
    end

    path = Tempfile.open(["d2rq-mapping", ".ttl"], "#{Rails.root}/tmp") { |fp|
      fp.print mapping_generator.generate
      fp.path
    }

    cmd = dump_rdf_cmd(path)

    last_event_id = request.headers['HTTP_LAST_EVENT_ID'] || 0
    if last_event_id == 0
      last_event_id = params['lastEventId'] || 0
    end
    
    if params.key?("sse")
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['Connection'] = 'keep-alive'
      response.headers['X-Accel-Buffering'] = 'no'
      mode = "sse"
    elsif params.key?("nosse")
      mode = "nosse"
    else
      response.headers['Content-Type'] = 'text/turtle'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['Content-Disposition'] = %Q(attachment; filename="#{@work.name}.ttl")
      mode = "download"
    end

    if params.key?("nosse")
      exec_render_dump_rdf(cmd)
    else
      num_lines = 0
      stdin, stdoe, thread = Open3.popen2e(cmd)
      stdin.close

      if mode == "sse"
        response.stream.write(":#{' ' * 2048}\n")
        response.stream.write("retry: 2000\n")
      end
      stdoe.each do |line|
        num_lines += 1
        case mode
        when "download", "show", "nosse"
          response.stream.write line
        when "sse"
          response.stream.write "id:#{last_event_id}\n"
          response.stream.write "data:#{line}\n"
        end
      end
    end

    if mode == "sse"
      response.stream.write("data:DONE\n\n")
    end
  rescue IOError
    logger.debug "Stream closed"
  ensure
    if mode != "nosse" && mode != "download"
      response.stream.close
      stdoe.close if stdoe
    end
  end

  
  def by_table
    class_map = ClassMap.find(params[:id])
    @work = class_map.work
    validate_user(@work.id)
    
    db_conn = DbConnection.where(work_id: @work.id).first

    db = TogoMapper::DB.new(db_conn.connection_config)
    if !class_map.table_name.blank? && !db.tables.include?(class_map.table_name)
      render text: "Table #{class_map.table_name} not found in database.", content_type: 'text/plain'
      return
    end

    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_class_map(class_map)
    mapping_generator.password = db_conn.decrypt_password
    mapping_generator.database_property = {
      'resultSizeLimit' => 5
    }
    mapping_generator.configuration_property = {
      'serveVocabulary' => false
    }

    path = Tempfile.open(["d2rq-mapping", ".ttl"], "#{Rails.root}/tmp") { |fp|
      fp.print mapping_generator.generate_by_class_map(true)
      fp.path
    }
    cmd = dump_rdf_cmd(path)

    if xhr?
      set_headers_for_cross_domain
      response_json(cmd)
    else
      exec_render_dump_rdf(cmd)
    end
  end


  def by_column
    property_bridge = PropertyBridge.find(params[:id])
    @work = property_bridge.work
    validate_user(@work.id)
    
    db_conn = DbConnection.where(work_id: @work.id).first

    db = TogoMapper::DB.new(db_conn.connection_config)
    table_name = property_bridge.class_map.table_name
    if !property_bridge.column_name.blank? && !db.columns(table_name).include?(property_bridge.column_name)
      render text: "Column #{property_bridge.column_name} not found in table #{table_name}.", content_type: 'text/plain'
      return
    end
    
    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_property_bridge(property_bridge)
    mapping_generator.password = db_conn.decrypt_password
    mapping_generator.database_property = {
      'resultSizeLimit' => 5
    }
    mapping_generator.configuration_property = {
      'serveVocabulary' => false
    }

    path = Tempfile.open(["d2rq-mapping", ".ttl"], "#{Rails.root}/tmp") { |fp|
      fp.print mapping_generator.generate_by_property_bridge(true)
      fp.path
    }
    cmd = dump_rdf_cmd(path)

    if xhr?
      set_headers_for_cross_domain
      response_json(cmd)
    else
      exec_render_dump_rdf(cmd)
    end
  end


  def by_table_join
    table_join = TableJoin.find(params[:id])
    @work = table_join.work
    validate_user(@work.id)
    
    db_conn = DbConnection.where(work_id: @work.id).first

    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_table_join(table_join)
    mapping_generator.password = db_conn.decrypt_password
    mapping_generator.configuration_property = {
      'serveVocabulary' => false
    }

    path = Tempfile.open(["d2rq-mapping", ".ttl"], "#{Rails.root}/tmp") { |fp|
      fp.print mapping_generator.generate_by_table_join(true)
      fp.path
    }
    cmd = dump_rdf_cmd(path)

    render text: exec_dump_rdf(cmd), content_type: 'text/plain'
  end


  def preview
    validate_user

    db_conn = DbConnection.where(work_id: @work.id).first

    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_work(@work)
    mapping_generator.password = db_conn.decrypt_password

    mapping_generator.database_property = {
      'resultSizeLimit' => 1
    }

    mapping_generator.configuration_property = {
      'serveVocabulary' => false
    }

    path = Tempfile.open(["d2rq-mapping", ".ttl"], "#{Rails.root}/tmp") { |fp|
      fp.print mapping_generator.generate
      fp.path
    }

    cmd = dump_rdf_cmd(path)

    if xhr?
      set_headers_for_cross_domain
      response_json(cmd)
    else
      exec_render_dump_rdf(cmd)
    end
  rescue IOError => e
    logger.debug e.message
    logger.debug e.bactrace.join("\n")
    logger.debug "Stream closed"
  ensure
  end

  private

  def exec_render_dump_rdf(cmd)
    logger.debug(cmd)
    o, e, s = Open3.capture3(cmd)

    if (s.success?)
      render text: o, content_type: 'text/turtle'
    else
      render text: "The error occurred while generating RDF from D2RQ mapping.\nThe error message is as the following.\n\n#{e}", content_type: 'text/plain'
    end
  end

  
  def exec_dump_rdf(cmd)
    logger.debug(cmd)
    o, e, s = Open3.capture3(cmd)

    if (s.success?)
      o
    else
      "The error occurred while generating RDF from D2RQ mapping.\nThe error message is as the following.\n\n#{e}"
    end
  end


  def dump_rdf_cmd(mapping_file_path)
    if @work.base_uri.blank?
      "#{TogoMapper.dump_rdf} -format TURTLE #{mapping_file_path}"
    else
      "#{TogoMapper.dump_rdf} -format TURTLE -b #{@work.base_uri} #{mapping_file_path}"
    end
  end


  def set_work
    @work = Work.find(params[:id])
  end


  def set_html_body_class
    @html_body_class = 'rdf page-get'
  end


  def response_json(cmd)
    logger.debug(cmd)
    o, e, s = Open3.capture3(cmd)

    if (s.success?)
      data = common_json_data('100')
      data[:turtle] = o
    else
      data = common_json_data('900', "The error occurred while generating RDF from D2RQ mapping.\nThe error message is as the following.\n\n#{e}")
      data[:turtle] = ''
    end

    render_json(data)
  end

  
  def turtle_file_path
    "#{Rails.root}/data/turtle/#{@work.id}.ttl"
  end


  def latest_turtle_file?
    mapping_updated = @work.mapping_updated
    last_generation_date = TurtleGeneration.last_generation_date(@work.id)
    if last_generation_date
      if mapping_updated
        @turtle_is_latest = last_generation_date > mapping_updated
      else
        @turtle_is_latest = true
      end
    else
      @turtle_is_latest = false
    end
  end

end
