require 'timeout'
require 'tempfile'
require 'open3'
require 'togo_mapper/d2rq/mapping_generator'
require 'togo_mapper/namespace'

class SparqlController < ApplicationController
  include TogoMapper::Namespace

  before_action :authenticate_user!, :set_html_body_class
  protect_from_forgery except: [:search]

  def show
    validate_user
    @work = Work.find(params[:id])
    @prefixes = sparql_prefixes(@work.id)

    render layout: 'graph'
  end


  def search
    validate_user
    work_id = params[:id].to_i

    namespaces = namespaces_by_namespace_settings(work_id)
    query = params[:query].to_s.strip
    format = params[:output_format]

    set_instance_variables_for_mapping_data(params[:id])
    @password = @db_connection.decrypt_password

    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_work(@work)
    mapping_generator.password = @password
    path = Tempfile.open(["d2rq-", "-mapping.ttl"], "#{Rails.root}/tmp") { |fp|
      fp.print mapping_generator.generate
      fp.path
    }

    cmd_parts = ["#{TogoMapper.d2r_query} --verbose -f #{format} --timeout 60"]
    unless @work.base_uri.blank?
      cmd_parts << "-b #{@work.base_uri}"
    end
    cmd_parts << "#{path} '#{query}'"

    @password = ""

    cmd = cmd_parts.join(" ")

    @result, @stderr, @status = Open3.capture3(cmd)
  end

  def search_new
    validate_user
    work_id = params[:id].to_i

    query = params[:query].to_s.strip
    format = params[:output_format]

    set_instance_variables_for_mapping_data(params[:id])
    @password = @db_connection.decrypt_password

    mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
    mapping_generator.prepare_by_work(@work)
    mapping_generator.password = @password
    path = Tempfile.open(["d2rq-", "-mapping.ttl"], "#{Rails.root}/tmp") { |fp|
      fp.print mapping_generator.generate
      fp.path
    }

    cmd_parts = ["#{TogoMapper.d2r_query} --verbose -f #{format} --timeout 60"]
    unless @work.base_uri.blank?
      cmd_parts << "-b #{@work.base_uri}"
    end
    cmd_parts << "#{path} '#{query}'"

    @password = ""

    cmd = cmd_parts.join(" ")

    begin
      r1, w = IO.pipe
      r2, e = IO.pipe
      pid = spawn(cmd, out: w, err: e)
      puts pid
      puts `ps -eaf | grep #{pid}`
      pid, @status = Process.waitpid2(pid)
      w.close
      e.close
      @result = r1.read
      @stderr = r2.read
      r1.close
      r2.close
    rescue Timeout::Error
      Process.kill(:TERM, -pid)
      render nothing: true, status: :gateway_timeout
    rescue => e
      logger.debug e.message
      logger.debug e.backtrace.join("\n")
      render nothing: true, status: :internal_server_error
    end
  end

  private

  def sparql_prefixes(work_id)
    namespaces = namespaces_by_namespace_settings(work_id)
    namespaces.select{ |namespace| !%w(d2rq jdbc map).include?(namespace[:prefix]) }.map{ |namespace| "PREFIX #{namespace[:prefix].strip}: <#{namespace[:uri].strip}>" }.join("\n")
  end

  def set_html_body_class
    @html_body_class = 'page-get sparql'
  end

end
