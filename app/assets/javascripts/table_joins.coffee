# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
@TableJoin = {
  bind_ui: (property_bridges)->

    $("#table_join_l_table_class_map_id").change ->
      class_map_id = $("#table_join_l_table_class_map_id option:selected").val()
      $("#table_join_l_table_property_bridge_id").children().remove()
      for property_bridge in  property_bridges[class_map_id]
        $("#table_join_l_table_property_bridge_id").append($('<option>').attr({ value: property_bridge.value }).text(property_bridge.label))


    $("#table_join_i_table_class_map_id").change ->
      class_map_id = $("#table_join_i_table_class_map_id option:selected").val()

      $("#table_join_i_table_l_property_bridge_id").children().remove()
      $("#table_join_i_table_r_property_bridge_id").children().remove()

      if (class_map_id == "")
        $("#table_join_i_table_l_property_bridge_id").append($('<option>').attr({ value: "" }).text(""))
        $("#table_join_i_table_r_property_bridge_id").append($('<option>').attr({ value: "" }).text(""))
      else
        for property_bridge in property_bridges[class_map_id]
          $("#table_join_i_table_l_property_bridge_id").append($('<option>').attr({ value: property_bridge.value }).text(property_bridge.label))
          $("#table_join_i_table_r_property_bridge_id").append($('<option>').attr({ value: property_bridge.value }).text(property_bridge.label))


    $("#table_join_r_table_class_map_id").change ->
      class_map_id = $("#table_join_r_table_class_map_id option:selected").val()
      $("#table_join_r_table_property_bridge_id").children().remove()
      for property_bridge in property_bridges[class_map_id]
        $("#table_join_r_table_property_bridge_id").append($('<option>').attr({ value: property_bridge.value }).text(property_bridge.label))


    $('#intermediate_switch').change ->
      if $(this).is(':checked')
        $('#modal-join').addClass 'multiple'
        $('.element.intermediate select').prop 'disabled', false
      else
        $('#modal-join').removeClass 'multiple'
        $('.element.intermediate select').prop 'disabled', true

}
