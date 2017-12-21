# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
@Namespace = {
  bind_ui: ->
    $("#namespace-add-btn").click ->
      $.getScript "/namespace/add_form"

    $("td.delete > button").click ->
      $(this).closest("tr").remove()

    $("#namespace-close-btn").click ->
      window.close()
}
