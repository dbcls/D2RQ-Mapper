require 'togo_mapper/namespace'

class NamespacesController < ApplicationController
  include TogoMapper::Namespace

  before_action :authenticate_user!, :set_html_body_class

  def show
    validate_user
    
    @work = Work.find(params[:id])
    @class_map = ClassMap.first_class_map(@work.id)
    @enabled_class_maps = ClassMap.table_derived(@work.id).select(&:enable)
    @namespaces = namespaces_by_namespace_settings(@work.id)
  end


  def update
    validate_user
    validate_posted_data
    work_id = params[:id].to_i

    success_message = 'Namespaces have been saved successfully.'
    notice_message = "<br />#{@warnings.join('<br />')}"
    error_message = "<br />#{@errors.join('<br />')}"

    unless posted_data_error?
      notice_message = "#{notice_message}<br /><br />#{success_message}"
      ActiveRecord::Base.transaction do
        @work = Work.find(work_id)
        NamespaceSetting.where(work_id: work_id).destroy_all
        
        params[:prefix].zip(params[:uri]).each do |ns|
          namespace = Namespace.where(prefix: ns[0], uri: ns[1]).first
          if namespace.nil?
            namespace = Namespace.create!(prefix: ns[0], uri: ns[1], is_default: false)
          end

          NamespaceSetting.create!(work_id: work_id, namespace_id: namespace.id)
        end
        save_mapping_updated_time
      end
    end

    respond_to do |format|
      format.html {
        if posted_data_error?
          flash[:err] = error_message
        else
          if @warnings.empty?
            flash[:msg] = success_message
          else
            @status = 'notice'
            flash[:notice] = notice_message
          end
        end
        
        redirect_to namespace_url(work_id)
      }
      format.js {
        if posted_data_error?
          @error_message = error_message
          @success_message = nil
        else
          @success_message = success_message
        end
        
        unless @warnings.empty?
          @notice_message = notice_message
        end
      }
    end
  end


  def add_form
    respond_to do |format|
      format.js
    end
  end
  
  private

  def validate_posted_data
    @errors = []
    @warnings = []
    
    uri = {}
    prefixes = []
    params[:prefix].zip(params[:uri]).each do |ns|
      next if ns[0].blank?

      if uri.key?(ns[1])
      else
        uri[ns[1]] = [] unless uri.key?(ns[1])
      end
      uri[ns[1]] << ns[0]

      if prefixes.include?(ns[0])
        @errors << "The requested prefix #{ns[0]} is redefined as different URI."
      else
        prefixes << ns[0]
      end
    end

    @warnings = duplicated_uri_warnings(uri)
  end

  
  def duplicated_uri_warnings(uri_prefixes)
    lines = []
    uri_prefixes.keys.each do |uri|
      next if uri_prefixes[uri].size < 2
      lines << "The requested URI #{uri} was already saved as another prefix. (Prefixes: #{uri_prefixes[uri].join(', ')})"
    end

    lines
  end


  def posted_data_error?
    !@errors.empty?
  end

  
  def set_html_body_class
    @html_body_class = 'page-namespaces'
  end

end
