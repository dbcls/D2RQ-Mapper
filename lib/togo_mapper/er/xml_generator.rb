module TogoMapper
class ER
class XmlGenerator
  def initialize(work)
    @work = work
    @db_connection = @work.db_connection
    @db = TogoMapper::DB.new(@db_connection.connection_config)
  end

  def generate
    xml_elems = ['<sql align_table="true">']

    # work
    xml_elems << %Q(<work id="#{@work.id}" name="#{@work.name}">)
    xml_elems << '</work>'

    # tables
    ClassMap.where(work_id: @work.id).order(:id).each do |class_map|
      next if class_map.table_name.to_s.empty? || !class_map.bnode_id.nil?

      # Table information
      info = @db.client.pk_info(@db_connection['database'], class_map.table_name)

      xml_elems << %Q|<table name="#{class_map.table_name}" id="#{class_map.id}" enable="#{class_map.enable}" x="#{class_map.er_xpos}" y="#{class_map.er_ypos}">|

      # rows
      PropertyBridge.where(class_map_id: class_map.id).order(:id).each do |property_bridge|
        next unless property_bridge.property_bridge_type_id == 1
        xml_elems << %Q|<row name="#{property_bridge.column_name}" id="#{property_bridge.id}" enable="#{property_bridge.enable}">|

        # relations
        TableJoin.where('(l_table_class_map_id=? AND l_table_property_bridge_id=?) OR (r_table_class_map_id=? AND r_table_property_bridge_id=?) OR (i_table_class_map_id=? AND i_table_l_property_bridge_id=?) OR (i_table_class_map_id=? AND i_table_r_property_bridge_id=?)', class_map.id, property_bridge.id, class_map.id, property_bridge.id, class_map.id, property_bridge.id, class_map.id, property_bridge.id).each do |table_join|
          cm = nil
          pb = nil
          if table_join.i_table_class_map_id == class_map.id
            if table_join.i_table_l_property_bridge_id == property_bridge.id
              cm = ClassMap.find(table_join.l_table_class_map_id)
              pb = PropertyBridge.find(table_join.l_table_property_bridge_id)
            else
              cm = ClassMap.find(table_join.r_table_class_map_id)
              pb = PropertyBridge.find(table_join.r_table_property_bridge_id)
            end
          else
            unless info[:column_name] == property_bridge.column_name
              if table_join.l_table_class_map_id == class_map.id
                cm = ClassMap.find(table_join.r_table_class_map_id)
                pb = PropertyBridge.find(table_join.r_table_property_bridge_id)
              else
                cm = ClassMap.find(table_join.l_table_class_map_id)
                pb = PropertyBridge.find(table_join.l_table_property_bridge_id)
              end
            end
          end

          if cm && pb
            xml_elem = %Q(<relation id="#{table_join.id}" table="#{cm.table_name}" row="#{pb.column_name}" />)
            xml_elems << xml_elem
            xml_elems << xml_elem
          end
        end

        xml_elems << '</row>'
      end
      xml_elems << '</table>'
    end

    xml_elems << '</sql>'

    xml_elems.join("\n")
  end

end
end
end
