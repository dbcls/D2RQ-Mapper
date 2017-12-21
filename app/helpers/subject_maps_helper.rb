module SubjectMapsHelper

  def rdf_button_class(class_map)
    if class_map && class_map.enable
      "btn btn-primary btn-rdf btn-rdf-disable"
    else
      "btn btn-default btn-rdf btn-rdf-enable"
    end
  end


  def update_success_message(class_map)
    if class_map.for_join?
      table_name = class_map.table_join.label
    else
      table_name = class_map.table_name
    end

    if class_map.enable
      "Settings of table '#{table_name}' are included in a resulting mapping file."
    else
      "Settings of table '#{table_name}' are excluded from a resulting mapping file."
    end
  end

end
