require 'togo_mapper/mapping'

class TableJoinsController < ApplicationController
  include TogoMapper::Mapping

  def index
  end


  def create
    work_id = params[:table_join]['work_id'].to_i
    validate_user(work_id)
    errors = validate_param
    unless errors.empty?
      flash[:err] = errors.join('<br />')
    else
      ActiveRecord::Base.transaction do
        # create TableJoin model
        @table_join = TableJoin.create!(table_join_params)

        # ClassMap for table_join
        @class_map = create_class_map_for_table_join(@table_join)

        @table_join.class_map_id = @class_map.id
        @table_join.save!

        # PropertyBridge for table_join
        @property_bridge = create_property_bridge_for_table_join(@table_join)
        @table_join.property_bridge_id = @property_bridge.id
        @table_join.save!

        # PropertyBridge for rdfs:label
        create_models_for_label
      end
      flash[:msg] = "Setting of table join was successfully saved."
    end
    
    if params[:page] == 'er'
      redirect_to er_url(work_id)
    else
      redirect_to subject_map_url(work_id)
    end
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
    table_join = TableJoin.find(params[:id])
    work = Work.find(table_join.work_id)
    validate_user(work.id)

    ActiveRecord::Base.transaction do
      table_join.class_map.destroy if table_join.class_map
      table_join.property_bridge.destroy if table_join.property_bridge
      table_join.destroy

      flash[:msg] = "Setting of table join was successfully deleted."
      redirect_to subject_map_url(work.id)
    end
  end

  
  def subject_map
    @table_join = TableJoin.find(params[:id])
    @work = @table_join.work
    validate_user(@work.id)
    
    @cmps_ids = params["class_map_property_setting"].to_unsafe_h.keys
    @pbps_ids = params["property_bridge_property_setting"].to_unsafe_h.keys
    
    @errors = validate_subject_map
    unless @errors.empty?
      @target = 'Subject Mapping'
      render 'subject_map_validation_error', format: 'js'
      return
    end
    
    ActiveRecord::Base.transaction do
      delete_subject_classes(@table_join.class_map.id)
      add_subject_classes
      
      @cmps_ids.each do |cmps_id|
        update_class_map_property_setting(cmps_id)
      end

      @pbps_ids.each do |pbps_id|
        update_property_bridge_property_setting(pbps_id)
      end
    end

    @status = 'success'
    @message = "Subject mapping of JOIN '#{@table_join.label_for_join_dialog}' was successfully saved."
  end


  def predicate_object_map
    @table_join = TableJoin.find(params[:id])
    @work = @table_join.work
    validate_user(@work.id)
    
    ActiveRecord::Base.transaction do
      delete_predicates(@table_join.property_bridge.id)
      add_predicates

      params[:property_bridge_property_setting].to_unsafe_h.keys.each do |pbps_id|
        update_property_bridge_property_setting(pbps_id)
      end
    end
    @status = 'success'
    @message = "Predicate-Object mapping of JOIN '#{@table_join.label_for_join_dialog}' was successfully saved."
  end
 
  private

  def validate_param
    errors = []
    
    table_join_params = params[:table_join]
    if params.key?("intermediate") && params[:intermediate] == 1
      # m:n JOIN
      exist_join = TableJoin.exists?(
        l_table_class_map_id: table_join_params["l_table_class_map_id"],
        l_table_property_bridge_id: table_join_params["l_table_property_bridge_id"],
        i_table_class_map_id: table_join_params["i_table_class_map_id"],
        i_table_l_property_bridge_id: table_join_params["i_table_l_property_bridge_id"],
        i_table_r_property_bridge_id: table_join_params["i_table_r_property_bridge_id"],
        r_table_class_map_id: table_join_params["r_table_class_map_id"],
        r_table_property_bridge_id: table_join_params["r_table_property_bridge_id"]
      )
    else
      # 1:n JOIN
      exist_join = TableJoin.exists?(
        l_table_class_map_id: table_join_params["l_table_class_map_id"],
        l_table_property_bridge_id: table_join_params["l_table_property_bridge_id"],
        #i_table_l_property_bridge_id: table_join_params["i_table_l_property_bridge_id"],
        #i_table_class_map_id: table_join_params["i_table_class_map_id"],
        #i_table_r_property_bridge_id: table_join_params["i_table_r_property_bridge_id"],
        r_table_class_map_id: table_join_params["r_table_class_map_id"],
        r_table_property_bridge_id: table_join_params["r_table_property_bridge_id"]
      )
    end

    if exist_join
      errors << "The same JOIN has already been set."
    end

    errors
  end
  
  def create_class_map_for_table_join(table_join)
    # Setting of main (left) table
    subject_class_map_property_setting = ClassMapPropertySetting.where(
      class_map_id: table_join.l_table.id,
      class_map_property_id: ClassMapProperty.for_resource_identity.map(&:id)
    ).first

    rdftype_class_map_property_setting = ClassMapPropertySetting.where(
      class_map_id: table_join.l_table.id,
      class_map_property_id: ClassMapProperty.rdf_type.id
    ).first

    # ClassMap
    class_map = ClassMap.create!(
      work_id: table_join.work_id,
      enable: true,
      table_join_id: table_join.id
    )

    # Method to generate subject URI (URI pattern, URI column, Constant URI)
    ClassMapPropertySetting.create!(
      class_map_id: class_map.id,
      class_map_property_id: subject_class_map_property_setting.class_map_property_id,
      value: subject_class_map_property_setting.value
    )

    # rdf:type (d2rq:class)
    ClassMapPropertySetting.create!(
      class_map_id: class_map.id,
      class_map_property_id: ClassMapProperty.rdf_type.id,
      value: rdftype_class_map_property_setting.value
    )

    class_map
  end


  def create_property_bridge_for_table_join(table_join)
    # ClassMap setting of join (right) table
    join_table_subject_class_map_property_setting = ClassMapPropertySetting.where(
      class_map_id: table_join.r_table.id,
      class_map_property_id: ClassMapProperty.for_resource_identity.map(&:id)
    ).first

    property_bridges = PropertyBridge.where(class_map_id: table_join.r_table.id)
    table_name = table_join.r_table.table_name
    column_name = property_bridges[0].column_name

    default_property_bridge_predicate_property = PropertyBridgeProperty.predicate_default

    # PropertyBridge for this join
    property_bridge = PropertyBridge.create!(
      work_id: table_join.work_id,
      class_map_id: table_join.class_map_id,
      user_defined: false,
      enable: true,
      property_bridge_type_id: PropertyBridgeType.column.id
    )

    # Relation of ClassMap
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.by_property("belongsToClassMap").id,
      value: table_join.class_map.map_name
    )

    # Predicate
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: default_property_bridge_predicate_property.id,
      value: "rdfs:seeAlso"
    )

    # Object
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.where(property: join_table_subject_class_map_property_setting.class_map_property.property).first.id,
      value: join_table_subject_class_map_property_setting.value
    )

    # Language
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id,
      value: ""
    )

    # Datatype
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.datatype.id,
      value: ""
    )

    property_bridge
  end


  def create_models_for_label
    label_pb = PropertyBridge.where(
      class_map_id: @table_join.l_table.id,
      property_bridge_type_id: PropertyBridgeType.label.id
    ).first

    label_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: label_pb.id,
      property_bridge_property_id: PropertyBridgeProperty.literal_pattern.id
    ).first

    lang_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: label_pb.id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id
    ).first

    create_models_for_resource_label(@class_map, { label: label_pbps.value, lang: lang_pbps.value })
  end


  def table_join_params
    p = params.require(:table_join).permit(
      :work_id,
      :l_table_class_map_id,
      :l_table_property_bridge_id,
      :r_table_class_map_id,
      :r_table_property_bridge_id,
      :i_table_class_map_id,
      :i_table_l_property_bridge_id,
      :i_table_r_property_bridge_id
    )

    unless params.key?(:intermediate)
      p.delete(:i_table_class_map_id)
      p.delete(:i_table_l_property_bridge_id)
      p.delete(:i_table_r_property_bridge_id)
    end

    p
  end

end
