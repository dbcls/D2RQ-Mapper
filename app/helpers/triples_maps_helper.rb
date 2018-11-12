module TriplesMapsHelper

  def column_rdf_button_class(property_bridge)
    if property_bridge && property_bridge.enable
      "btn btn-primary btn-rdf btn-rdf-disable"
    else
      "btn btn-default btn-rdf btn-rdf-enable"
    end
  end


  def disp_table_selector?(options_for_table_selector)
    return true if options_for_table_selector.size > 1
    return false if options_for_table_selector.empty?

    options_for_table_selector[0][1].size > 1
  end
  
end
