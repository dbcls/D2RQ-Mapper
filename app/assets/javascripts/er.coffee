# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
class ER
  @show_message: (html) ->
    $("#er-message").remove()
    $("#area").append html

window.ER = ER
