# database table

class window.SQL.Table extends SQL.Visual

  constructor: (owner, name, x, y, z) ->
    @owner = owner
    @rows = []
    @keys = []
    @zIndex = 0
    @_ec = []
    
    @flag = false
    @selected = false
    super()
    @data.comment = ""
    
    @setTitle name
    @x = x or 0
    @y = y or 0

    @setZ z
    @snap()


  _build: ->
    @dom.container = OZ.DOM.elm "div", {className:"sqldesigner-table"}
    @dom.content = OZ.DOM.elm "table"
    @dom.thead = OZ.DOM.elm "thead", {className: "sqldesigner-tablename"}
    @dom.tr = OZ.DOM.elm "tr"
    @dom.title = OZ.DOM.elm "td", {className: "sqldesigner-title"}
    @dom.rdfbtn = OZ.DOM.elm "td", {className: "er-table-rdf-btn btn btn-rdf"}
    
    OZ.DOM.append(
      [@dom.container, @dom.content],
      [@dom.content, @dom.thead],
      [@dom.thead, @dom.tr],
      [@dom.tr, @dom.title],
      [@dom.tr, @dom.rdfbtn]
    )
    
    @dom.mini = OZ.DOM.elm("div", {className:"sqldesigner-mini"});
    @owner.map.dom.container.appendChild(@dom.mini);

    @_ec.push( OZ.Event.add @dom.container, "dblclick",   @dblclick.bind(this) )
    @_ec.push( OZ.Event.add @dom.container, "mousedown",  @down.bind(this) )
    @_ec.push( OZ.Event.add @dom.container, "touchstart", @down.bind(this) )
    @_ec.push( OZ.Event.add @dom.container, "touchmove",  OZ.Event.prevent )
    @_ec.push( OZ.Event.add @dom.rdfbtn,    "click",      @rdfbtn_click.bind(this) )

    $(@dom.thead).droppable {
      accept: ".rdf-class",
      onDragEnter: (event, source) ->
      onDragLeave: (event, source) ->
      onDrop: (event, source) ->
        class_map_id = $(event.target).attr "data-cmid"
        rdf_class = $(source).text()
        $.getScript "/ajax/er/subject_map_dialog/#{class_map_id}?class=#{rdf_class}"
        $("#staticModalSubjectMap").modal()
    }


  setTitle: (t) ->
    old = @getTitle()
    for row in @rows
      for r in row.relations
        if r.row1 isnt row
          continue
        tt = row.getTitle().replace(new RegExp(old, "g"), t)
        if tt isnt row.getTitle()
          row.setTitle tt

    $(@dom.thead).attr "id", t
    SQL.Visual.prototype.setTitle.apply this, [t]


  getRelations: ->
    arr = []
    for row in @rows
      for r in row.relations
        if arr.indexOf(r) is -1
          arr.push r

    arr


  showRelations: ->
    for relation in @getRelations()
      relation.show()


  hideRelations: ->
    for relation in @getRelations()
      relation.hide()

  ###
  click: (e) ->
    OZ.Event.stop e
    t = OZ.Event.target e
    @owner.tableManager.select this
    
    if t isnt @dom.title
      # click on row
      return

    SQL.publish "tableclick", this
    @owner.rowManager.select false
  ###


  dblclick: (e) ->
    class_map_id = $(@dom.thead).attr "data-cmid"
    $.getScript "/ajax/er/subject_map_dialog/#{class_map_id}"


  select: ->
    if @selected
      return

    @selected = true
    OZ.DOM.addClass @dom.container, "selected"
    OZ.DOM.addClass @dom.mini, "mini_selected"
    @redraw()


  deselect: ->
    if not @selected
      return

    @selected = false
    OZ.DOM.removeClass @dom.container, "selected"
    OZ.DOM.removeClass @dom.mini, "mini_selected"
    @redraw()


  addRow: (title, data) ->
    row = new SQL.Row(this, title, data)
    @rows.push row
    @dom.content.appendChild row.dom.container
    @redraw()

    row


  removeRow: (r) ->
    idx = @rows.indexOf r
    if idx isnt -1
      return

    r.destroy()
    @rows.splice idx, 1
    @redraw()


  addKey: (name) ->
    k = new SQL.Key this, name
    @keys.push k

    k


  removeKey: (k) ->
    idx = this.keys.indexOf k
    if idx isnt -1
      return

    k.destroy()
    @keys.splice idx, 1


  redraw: ->
    x = @x
    y = @y
    if @selected
      x--
      y--

    @dom.container.style.left = x + "px"
    @dom.container.style.top = y + "px"
    
    ratioX = @owner.map.width / @owner.width
    ratioY = @owner.map.height / @owner.height
    
    w = @dom.container.offsetWidth * ratioX
    h = @dom.container.offsetHeight * ratioY
    x = @x * ratioX
    y = @y * ratioY
    
    @dom.mini.style.width = Math.round(w) + "px"
    @dom.mini.style.height = Math.round(h) + "px"
    @dom.mini.style.left = Math.round(x) + "px"
    @dom.mini.style.top = Math.round(y) + "px"

    @width = @dom.container.offsetWidth
    @height = @dom.container.offsetHeight
    
    # for D2RQ Mapper
    $(@dom.thead).attr "data-cmid", @class_map_id
    if not @enable
      $(@dom.thead).addClass "disable"
      $(@dom.rdfbtn).removeClass("btn-primary").removeClass("btn-rdf-disable").addClass("btn-default").addClass("btn-rdf-enable")
    else
      $(@dom.thead).removeClass "disable"
      $(@dom.rdfbtn).removeClass("btn-default").removeClass("btn-rdf-enable").addClass("btn-primary").addClass("btn-rdf-disable")

    for relation in @getRelations()
      relation.redraw()


  moveBy: (dx, dy) ->
    @x += dx
    @y += dy
    
    @snap()
    @redraw()


  moveTo: (x, y) ->
    @x = x
    @y = y

    @snap()
    @redraw()


  snap: ->
    snap = parseInt @owner.getOption("snap")
    if snap
      @x = Math.round(@x / snap) * snap
      @y = Math.round(@y / snap) * snap


  # mousedown - start drag 
  down: (e) ->
    OZ.Event.stop e
    t = OZ.Event.target e
    if t isnt @dom.title
      # on a row
      return
    
    # touch?
    if e.type is "touchstart"
      event = e.touches[0]
      moveEvent = "touchmove"
      upEvent = "touchend"
    else
      event = e
      moveEvent = "mousemove"
      upEvent = "mouseup"
    
    # a non-shift click within a selection preserves the selection
    if e.shiftKey or not @selected
      @owner.tableManager.select this, e.shiftKey

    t = SQL.Table
    t.active = @owner.tableManager.selection
    n = t.active.length
    t.x = new Array(n)
    t.y = new Array(n)
    for i in [0 ... n]
      # position relative to mouse cursor
      t.x[i] = t.active[i].x - event.clientX
      t.y[i] = t.active[i].y - event.clientY
    
    if @owner.getOption "hide"
      for i in [0 ... n]
        t.active[i].hideRelations()
    
    @documentMove = OZ.Event.add document, moveEvent, @move.bind(this)
    @documentUp = OZ.Event.add document, upEvent, @up.bind(this)


  rdfbtn_click: (e) ->
    OZ.Event.stop e
    rdfbtn = OZ.Event.target e
    thead = $(rdfbtn).closest "thead"
    table_name = $(thead).attr "id"
    class_map_id = $(thead).attr "data-cmid"

    table = @owner.findNamedTable table_name

    $.ajax {
      url: "/class_maps/#{class_map_id}/toggle_enable",
      type: 'POST',
      success: (data) ->
        table.enable = not table.enable
        if table.enable
          $("##{table_name}").removeClass "disable"
          $(rdfbtn).removeClass("btn-default").removeClass("btn-rdf-enable").addClass("btn-primary").addClass("btn-rdf-disable")
        else
          $("##{table_name}").addClass "disable"
          $(rdfbtn).removeClass("btn-primary").removeClass("btn-rdf-disable").addClass("btn-default").addClass("btn-rdf-enable")
      error: (XMLHttpRequest, textStatus, errorThrown) ->
        alert "Error !"
    }


  toXML: ->
    t = @getTitle().replace /"/g, "&quot;"
    xml = "<table id=\"#{@class_map_id}\" enable=\"#{@enable}\" x=\"#{@x}\" y=\"#{@y}\" name=\"#{t}\">\n"
    
    for row in @rows
      xml += row.toXML()
    
    for key in @keys
      xml += key.toXML();

    c = @getComment()
    if c
      xml += "<comment>" + SQL.escape(c) + "</comment>\n"
    
    xml += "</table>\n";

    xml


  fromXML: (node) ->
    name = node.getAttribute "name"
    @setTitle name

    x = parseInt(node.getAttribute "x") or 0
    y = parseInt(node.getAttribute "y") or 0
    if x > 0 or y > 0
      @owner.align_table = false
    @moveTo x, y

    class_map_id = node.getAttribute "id"
    @class_map_id = class_map_id

    enable = node.getAttribute "enable"
    if enable is "true"
      @enable = true
    else
      @enable = false

    rows = node.getElementsByTagName "row"
    for row in rows
      r = @addRow ""
      r.fromXML row

    keys = node.getElementsByTagName "key"
    for key in keys
      k = @addKey()
      k.fromXML key

    for ch in node.childNodes
      if ch.tagName and ch.tagName.toLowerCase() is "comment" and ch.firstChild
        @setComment ch.firstChild.nodeValue


  getZ: ->
    @zIndex


  setZ: (z) ->
    #@zIndex = z
    #@dom.container.style.zIndex = z


  #  return row with a given name
  findNamedRow: (name) ->
    for row in @rows
      if row.getTitle() is name
        return row

    false


  setComment: (c) ->
    @data.comment = c
    @dom.title.title = @data.comment


  getComment: ->
    @data.comment


  # mousemove
  move: (e) ->
    t = SQL.Table
    #SQL.Designer.removeSelection()
    @owner.removeSelection()
    if e.type is "touchmove"
      if e.touches.length > 1
        return
      event = e.touches[0]
    else
      event = e

    for i in [0 ... t.active.length]
      x = t.x[i] + event.clientX
      y = t.y[i] + event.clientY
      x = Math.max x, 0
      y = Math.max y, 0
      t.active[i].moveTo x, y


  up: (e) ->
    t = SQL.Table
    d = SQL.Designer
    #if d.getOption "hide"
    if @owner.getOption "hide"
      for i in [0 ... t.active.length]
        t.active[i].showRelations()
        t.active[i].redraw()

    t.active = false
    OZ.Event.remove @documentMove
    OZ.Event.remove @documentUp
    @owner.sync()


  destroy: ->
    SQL.Visual.prototype.destroy.apply this
    @dom.mini.parentNode.removeChild @dom.mini
    while @rows.length
      @removeRow @rows[0]

    @_ec.forEach OZ.Event.remove, OZ.Event
