require 'rdf/turtle'
require 'togo_mapper/namespace'

module TogoMapper
module D2RQ

  def default_resource_uri_pattern(class_map)
    "@@#{class_map.table_name}.#{class_map.pk_column_name}@@"
  end

  
  def default_class_map_rdf_type(class_map)
    rdf_type = ""

    if class_map.table_name
      rdf_type = class_map.table_name
    else
      table_join = class_map.table_join
      if table_join
        rdf_type = table_join.r_table.table_name
      end
    end

    rdf_type
  end


  def default_resource_label_predicate
    "rdfs:label"
  end


  def default_resource_label_object(class_map)
    if class_map.table_name
      "@@#{class_map.table_name}.#{class_map.pk_column_name}@@"
    else
      table_join = class_map.table_join
      if table_join
        "@@#{table_join.l_table.table_name}.#{table_join.l_table.pk_column_name}@@"
      end
    end
  end


  def default_resource_label_lang
    ""
  end

end
end
