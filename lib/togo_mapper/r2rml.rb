require 'rdf/turtle'
require 'togo_mapper/db'

module TogoMapper
module R2RML

  @@ommit_table_name = true
  @@prefixes = { rr: "http://www.w3.org/ns/r2rml#" }
  
  def generate_mapping
    @namespaces.each do |ns|
      @@prefixes[ns[:prefix].to_sym] = ns[:uri]
    end
    
    ignored_class_map_names = []
    
    RDF::Turtle::Writer.buffer(prefixes: @@prefixes) do |writer|

      @@ommit_table_name = true
      @class_maps.each do |class_map|
        unless class_map.enable
          ignored_class_map_names << class_map.map_name
          next
        end

        if class_map.class_map_property_settings.empty?
          ignored_class_map_names << class_map.map_name
          next
        end

        unless class_map.property_setting_for_resource_identity
          ignored_class_map_names << class_map.map_name
          next
        end

        next if class_map.table_name.blank?

        pb_hash = class_map.divide_property_bridge_by_condition
        add_triples_map(writer, "", class_map, pb_hash[:without_condition])

        pb_hash[:with_condition].each do |property_bridge|
          add_triples_map(writer, "", class_map, [property_bridge])
        end
      end

      @@ommit_table_name = false
      @table_joins.each do |table_join|
        class_map = table_join.class_map
        next if ignored_class_map_names.include?(class_map.map_name)

        PropertyBridge.where(class_map_id: class_map.id, property_bridge_type_id: PropertyBridgeType.column.id).each do |property_bridge|
          add_triples_map(writer, property_bridge.map_name, class_map, [property_bridge])
        end
      end
      
    end
  end


  def add_triples_map(writer, map_name, class_map, property_bridges)
    return if property_bridges.empty?

    cm_sql_where_condition = class_map.query_where_condition
    pb_sql_where_condition = property_bridges[0].query_where_condition
    if !cm_sql_where_condition.blank? && !pb_sql_where_condition.blank?
      sql_where_condition = "#{cm_sql_where_condition} AND #{pb_sql_where_condition}"
    else
      sql_where_condition = cm_sql_where_condition + pb_sql_where_condition
    end

    if map_name.blank?
      if sql_where_condition.blank? || pb_sql_where_condition.blank?
        triples_map_subject = RDF::URI("##{class_map.map_name}")
      else
        triples_map_subject = RDF::URI("##{property_bridges[0].map_name}")
      end
    else
      triples_map_subject = RDF::URI("##{map_name}")
    end

    # rr:logicalTable
    add_logical_table(writer, triples_map_subject, class_map, sql_where_condition)

    # rr:subjectMap
    add_subject_map(writer, triples_map_subject, class_map)

    # rr:predicateObjectMap
    property_bridges.each do |property_bridge|
      next unless property_bridge.enable
      next if property_bridge.class_map.for_bnode? && property_bridge.for_label?
      add_predicate_object_map(writer, triples_map_subject, property_bridge)
    end
  end


  def add_logical_table(writer, triples_map_subject, class_map, sql_where_condition)
    logical_table_bnode = add_logical_table_bnode(writer, class_map, sql_where_condition)
    writer << RDF::Statement(triples_map_subject,
                             RDF::URI("#{@@prefixes[:rr]}logicalTable"),
                             logical_table_bnode)
  end
  
  
  def add_logical_table_bnode(writer, class_map, sql_where_condition)
    bnode = RDF::Node.new
    
    if class_map.table_derived?
      if sql_where_condition.blank?
        writer << RDF::Statement(
          bnode,
          RDF::URI("#{@@prefixes[:rr]}tableName"),
          RDF::Literal(class_map.table_name)
        )
      else
        db = TogoMapper::DB.new(@db_connection.connection_config)
        sql = db.client.query_for_one_table(class_map.table_name, sql_where_condition)
        writer << RDF::Statement(
          bnode,
          RDF::URI("#{@@prefixes[:rr]}sqlQuery"),
          RDF::Literal(sql)
        )
      end
    elsif class_map.for_join?
      db = TogoMapper::DB.new(@db_connection.connection_config)
      table_join = class_map.table_join
      l_table = table_join.l_table
      r_table = table_join.r_table
      i_table = table_join.i_table
      if table_join.multiple_join?
        sql = db.client.sql_for_many2many_join(l_table.table_name,
                                               table_join.l_column.column_name,
                                               db.columns(l_table.table_name),
                                               r_table.table_name,
                                               table_join.r_column.column_name,
                                               db.columns(r_table.table_name),
                                               i_table.table_name,
                                               table_join.i_l_column.column_name,
                                               table_join.i_r_column.column_name)
      else
        sql = db.client.sql_for_one2many_join(l_table.table_name,
                                              table_join.l_column.column_name,
                                              db.columns(l_table.table_name),
                                              r_table.table_name,
                                              table_join.r_column.column_name,
                                              db.columns(r_table.table_name))
      end

      unless sql_where_condition.blank?
        sql = "#{sql} AND #{sql_where_condition}"
      end
        
      writer << RDF::Statement(
        bnode,
        RDF::URI("#{@@prefixes[:rr]}sqlQuery"),
        RDF::Literal(sql)
      )
    end

    bnode
  end


  def add_subject_map(writer, triples_map_subject, class_map)
    subject_map_bnode = RDF::Node.new
    class_map.class_map_property_settings.each do |class_map_property_setting|
      next if class_map.for_bnode? && class_map_property_setting.class_map_property.property == "d2rq:class"
      add_subject_map_bnode(writer, subject_map_bnode, class_map, class_map_property_setting)
    end
    writer << RDF::Statement(triples_map_subject, RDF::URI("#{@@prefixes[:rr]}subjectMap"), subject_map_bnode)
  end

  
  def add_subject_map_bnode(writer, subject, class_map, class_map_property_setting)
    case class_map_property_setting.class_map_property.property
    when 'd2rq:uriPattern'
      writer << RDF::Statement(
        subject,
        RDF::URI("#{@@prefixes[:rr]}template"),
        RDF::Literal(d2rq_pattern_to_r2rml_pattern(class_map_property_setting.value))
      )
    when 'd2rq:bNodeIdColumns'
      statements_for_blank_node(subject, class_map).each do |statement|
        writer << statement
      end
    when 'd2rq:class'
      writer << RDF::Statement(
        subject,
        RDF::URI("#{@@prefixes[:rr]}class"),
        RDF::URI(uri_value(class_map_property_setting.value))
      )
    end
  end
  

  # [] rr:predicateObjectMap [
  #    rr:predicate <conferences#ConfID>
  #    rr:objectMap [
  #                   rr:column "ConfID";
  #                   rr:termType rr:Literal
  #    ];
  # ]
  def add_predicate_object_map(writer, triples_map_subject, property_bridge)
    bnode_for_pred_obj = RDF::Node.new
    bnode_for_object = RDF::Node.new
    property_bridge.property_bridge_property_settings.each do |property_bridge_property_setting|
      if property_bridge_property_setting.property_bridge_property.property == 'd2rq:property'
        add_property(writer, bnode_for_pred_obj, property_bridge_property_setting.value)
      else
        add_object_map_bnode(writer, bnode_for_object, property_bridge, property_bridge_property_setting)
      end
    end

    # [<bnode_for_pred_obj>] rr:objectMap [<bnode_for_object>]
    add_object_map(writer, bnode_for_pred_obj, bnode_for_object)

    # [<subject>] rr:predicateObjectMap [<bnode_for_pred_obj>]
    writer << RDF::Statement(triples_map_subject,
                             RDF::URI("#{@@prefixes[:rr]}predicateObjectMap"),
                             bnode_for_pred_obj)
  end

  
  #  [<bnode_for_pred_obj>] rr:predicate <conferences#ConfID>
  def add_property(writer, subject, object_value)
    writer << RDF::Statement(
      subject,
      RDF::URI("#{@@prefixes[:rr]}predicate"),
      RDF::URI(uri_value(object_value))
    )
  end

  
  #  [] rr:column "ConfID";
  #     rr:termType rr:Literal
  def add_object_map_bnode(writer, subject_for_object, property_bridge, property_bridge_property_setting)
    if property_bridge.bnode_id
      blank_node = BlankNode.find(property_bridge.bnode_id)
      class_map = ClassMap.where(bnode_id: blank_node.id).first
      statements_for_blank_node(subject_for_object, class_map).each do |statement|
        writer << statement
      end
    else
      statements_for_property_map(subject_for_object, property_bridge_property_setting).each do |statement|
        writer << statement
      end
    end
  end


  def statements_for_property_map(subject, property_bridge_property_setting)
    case property_bridge_property_setting.property_bridge_property.property
    when 'd2rq:column'
      [
        RDF::Statement(
          subject,
          RDF::URI("#{@@prefixes[:rr]}column"),
          RDF::Literal(d2rq_column_to_r2rml_column(property_bridge_property_setting.value))
        ),
        RDF::Statement(
          subject,
          RDF::URI("#{@@prefixes[:rr]}termType"),
          RDF::URI("#{@@prefixes[:rr]}Literal")
        )
      ]
    when 'd2rq:pattern'
      [
        RDF::Statement(
          subject,
          RDF::URI("#{@@prefixes[:rr]}template"),
          RDF::Literal(d2rq_pattern_to_r2rml_pattern(property_bridge_property_setting.value))
        ),
        RDF::Statement(
          subject,
          RDF::URI("#{@@prefixes[:rr]}termType"),
          RDF::URI("#{@@prefixes[:rr]}Literal")
        )
      ]
    when 'd2rq:uriColumn'
      [
        RDF::Statement(
          subject,
          RDF::URI("#{@@prefixes[:rr]}column"),
          RDF::Literal(d2rq_column_to_r2rml_column(property_bridge_property_setting.value))
        )
      ]
    when 'd2rq:uriPattern'
      [
        RDF::Statement(
          subject,
          RDF::URI("#{@@prefixes[:rr]}template"),
          RDF::Literal(d2rq_pattern_to_r2rml_pattern(property_bridge_property_setting.value))
        )
      ]
    when 'd2rq:datatype'
      unless property_bridge_property_setting.value.blank?
        [
          RDF::Statement(
            subject,
            RDF::URI("#{@@prefixes[:rr]}datatype"),
            RDF::URI(uri_value(property_bridge_property_setting.value))
          )
        ]
      else
        []
      end
    else
      []
    end
  end
  
  
  def add_object_map(writer, subject, object)
    writer << RDF::Statement(
      subject,
      RDF::URI("#{@@prefixes[:rr]}objectMap"),
      object
    )
  end


  def statements_for_blank_node(subject, class_map)
    [
      RDF::Statement(
        subject,
        RDF::URI("#{@@prefixes[:rr]}template"),
        RDF::Literal(class_map.bnode_name_tmpl_for_r2rml)
      ),
      RDF::Statement(
        subject,
        RDF::URI("#{@@prefixes[:rr]}termType"),
        RDF::URI("#{@@prefixes[:rr]}BlankNode")
      )
    ]
  end

  
  def d2rq_pattern_to_r2rml_pattern(s)
    if @@ommit_table_name
      s.gsub(/@@[^\.@]*\.([^@]+)@@/){ "{#{$1}}" }
    else
      s.gsub(/@@(.*?)@@/){ "{#{$1}}" }
    end
  end


  def d2rq_column_to_r2rml_column(s)
    if @@ommit_table_name
      if /.*\.(.+)/ =~ s
        $1
      else
        s
      end
    else
      s
    end
  end


  def uri_value(value)
    pos = value.index(':')
    if pos.nil?
      value
    else
      if pos > 0
        prefix = value[0 .. pos - 1]
        if @@prefixes.key?(prefix.to_sym)
          "#{@@prefixes[prefix.to_sym]}#{value[pos + 1 .. -1]}"
        else
          value
        end
      else
        value
      end
    end
  end

end
end
