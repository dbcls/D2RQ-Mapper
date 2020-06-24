require_dependency 'togo_mapper/mapping'
require_dependency 'togo_mapper/d2rq'
require_dependency 'togo_mapper/d2rq/bnode'

class BlankNodesController < ApplicationController
  include TogoMapper::D2RQ::Bnode

  def index
  end


  def create
    work_id = params[:work_id]
    validate_user(work_id)

    @work = Work.find(work_id)
    property_bridge_ids = [ params[:property_bridge_id].to_i ]

    create_blank_node(property_bridge_ids, params[:class_map_id].to_i)

    flash[:msg] = "New blank node was successfully created."
    redirect_to subject_map_url(@work.id)
  end


  def new
  end


  def edit
  end


  def show
  end


  def update
  end


  def destroy
    blank_node = BlankNode.find(params[:id])
    work = Work.find(blank_node.work_id)
    validate_user(work.id)

    destroy_blank_node(blank_node)

    flash[:msg] = "Setting of blank node was successfully deleted."
    redirect_to subject_map_url(work.id)
  end

end
