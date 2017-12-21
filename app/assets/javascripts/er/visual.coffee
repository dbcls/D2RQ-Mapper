# base visual element

class window.SQL.Visual
  constructor: ->
    @_init()
    @_build()

  _init: ->
    @dom =
      container: null
      title: null
    @data =
      title: ""

  
  _build: ->
  _toXML: ->
  _fromXML: ->
  _redraw: ->

  # destructor
  destroy: ->
    p = this.dom.container.parentNode
    if p and p.nodeType is 1
      p.removeChild this.dom.container


  setTitle: (title) ->
    if not title
      return
    @data.title = title
    @dom.title.innerHTML = title


  getTitle: ->
    @data.title

