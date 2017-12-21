# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
sparql = ->
  $("#sparql-form").on "ajax:error", (e, xhr, status, error) ->
    $("#sparql-result").html "<pre><code>#{xhr.statusText} (HTTP Status: #{xhr.status})</code></pre>"
    $("#sparql-running-icon").hide()
    $("#sparql-result").show()

$(document).ready sparql
$(document).on 'page:load', sparql
