require 'open3'
require 'tempfile'
require 'togo_mapper/d2rq/mapping_generator'

module TogoMapper
module D2RQ
class TurtleGenerator

  class GenerateError < StandardError; end
  
  def initialize(work_id, data_dir, tmp_dir, generation_id = nil)
    @work = Work.find(work_id)
    @data_dir = data_dir
    @tmp_dir = tmp_dir

    if generation_id
      @generation = TurtleGeneration.find(generation_id)
    else
      @generation = nil
    end
    
    @db_conn = DbConnection.where(work_id: @work.id).first
  end


  def generate
    begin
      if @generation
        @generation.status = 'RUNNINIG'
        @generation.start_date = Time.now
        @generation.save!
      end
    
      mapping_generator = TogoMapper::D2RQ::MappingGenerator.new
      mapping_generator.prepare_by_work(@work)
      mapping_generator.password = @db_conn.decrypt_password

      path = Tempfile.open(['d2rq-mapping', '.ttl'], @tmp_dir) { |fp|
        fp.print mapping_generator.generate
        fp.path
      }
    
      exec_dump_rdf(path, tmp_turtle_file_path)
      File.rename(tmp_turtle_file_path, turtle_file_path)

      if @generation
        @generation.status = 'SUCCESS'
        @generation.end_date = Time.now
        @generation.save!
      end
    rescue => e
      if @generation
        @generation.status = 'ERROR'
        @generation.error_message = e.message
        @generation.end_date = Time.now
        @generation.save!
      else
        raise e
      end
    end
  end

  private

  def exec_dump_rdf(mapping_file_path, output_file_path = nil)
    cmd = dump_rdf_cmd(mapping_file_path, output_file_path)
    
    output = ''
    error = ''
    status = Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      if @generation
        @generation.pid = wait_thr.pid
        @generation.save!
      end
      output = stdout.read
      error = stderr.read

      wait_thr.value
    end

    if status.signaled?
      raise GenerateError, "The turtle generation process was interrupted by signal #{status.termsig}."
    else
      unless status.success?
        raise GenerateError, "The error occurred while generating RDF from D2RQ mapping.\nThe error message is as the following.\n\n#{error}"
      end
    end
  end

  
  def dump_rdf_cmd(mapping_file_path, output_file_path = nil)
    cmd = [ TogoMapper.dump_rdf, '-format TURTLE' ]

    unless @work.base_uri.blank?
      cmd << "-b #{@work.base_uri}"
    else
      cmd << "-b http://localhost:2020/"
    end

    unless output_file_path.nil?
      cmd << "-o #{output_file_path}"
    end

    cmd << mapping_file_path

    cmd.join(' ')
  end


  def turtle_file_name
    "#{@work.id}.ttl"
  end


  def turtle_file_path
    "#{@data_dir}/#{turtle_file_name}"
  end

  
  def tmp_turtle_file_path
    "#{@tmp_dir}/#{turtle_file_name}"
  end
  
end
end
end
