# table manager

class window.SQL.TableManager
  
  constructor: (@owner) ->
    @dom = {
      container: OZ.$("table"),
      name: OZ.$("tablename"),
      comment: OZ.$("tablecomment")
    }
    @selection = []
    @adding = false
    
    ids = [
      "aligntables",
      "addtable",
      "removetable",
      "cleartables",
      "addrow",
      "edittable",
      "tablekeys"
    ]
    for id in ids
      elm = OZ.$(id)
      @dom[id] = elm
      elm.value = _(id)

    ids = [
      "tablenamelabel",
      "tablecommentlabel"
    ]
    for id in ids
      elm = OZ.$(id)
      elm.innerHTML = _(id);
    
    @select false
    
    @save = @save.bind this
    
    OZ.Event.add "area", "click", @click.bind(this)
    OZ.Event.add @dom.addtable, "click", @preAdd.bind(this)
    OZ.Event.add @dom.removetable, "click", @remove.bind(this)
    OZ.Event.add @dom.cleartables, "click", @clear.bind(this)
    OZ.Event.add @dom.addrow, "click", @addRow.bind(this)
    OZ.Event.add @dom.aligntables, "click", @owner.alignTables.bind(@owner)
    OZ.Event.add @dom.edittable, "click", @edit.bind(this)
    OZ.Event.add @dom.tablekeys, "click", @keys.bind(this)
    OZ.Event.add document, "keydown", @press.bind(this)

    @dom.container.parentNode.removeChild @dom.container


  addRow: (e) ->
    newrow = @selection[0].addRow _("newrow")
    @owner.rowManager.select newrow
    newrow.expand()


  # activate table
  select: (table, multi) ->
    if table
      if multi
        i = @selection.indexOf table
        if i < 0
          @selection.push table
        else
          @selection.splice i, 1
      else
        if @selection[0] is table
          return
        @selection = [table]
    else
      @selection = []

    @processSelection()


  processSelection: ->
    for table in @owner.tables
      table.deselect()
      
    if @selection.length is 1
      #@dom.addrow.disabled = false
      #@dom.edittable.disabled = false
      #@dom.tablekeys.disabled = false
      @dom.removetable.value = _("removetable")
    else
      #@dom.addrow.disabled = true
      #@dom.edittable.disabled = true
      #@dom.tablekeys.disabled = true

    if @selection.length
      #@dom.removetable.disabled = false
      if @selection.length > 1
        @dom.removetable.value = _("removetables")
    else
      #@dom.removetable.disabled = true
      @dom.removetable.value = _("removetable")

    for t in @selection
      t.owner.raise t
      t.select()


  # select all tables intersecting a rectangle
  selectRect: (x, y, width, height) ->
    @selection = []
    tables = 
    x1 = x + width
    y1 = y + height
    for table in @owner.tables
      tx = table.x
      tx1 = table.x + table.width
      ty = table.y
      ty1 = table.y + table.height
      if ( (tx >= x and tx < x1) or (tx1 >= x and tx1 < x1) or (tx < x and tx1 > x1) ) and ( (ty >= y and ty < y1) or (ty1 >= y and ty1 < y1) or (ty < y and ty1 y 1) )
        @selection.push table

    @processSelection()


  # finish adding new table
  click: (e) ->
    newtable = false
    if @adding
      @adding = false
      OZ.DOM.removeClass "area","adding"
      @dom.addtable.value = @oldvalue
      scroll = OZ.DOM.scroll()
      x = e.clientX + scroll[0]
      y = e.clientY + scroll[1]
      newtable = @owner.addTable _("newtable"), x, y
      row = newtable.addRow "id", {ai: true}
      key = newtable.addKey "PRIMARY", ""
      key.addRow row

    @select newtable
    @owner.rowManager.select false
    if @selection.length is 1
      @edit e


  # click add new table
  preAdd: (e) ->
    if @adding
      @adding = false
      OZ.DOM.removeClass "area", "adding"
      @dom.addtable.value = @oldvalue
    else
      @adding = true
      OZ.DOM.addClass "area", "adding"
      @oldvalue = @dom.addtable.value
      @dom.addtable.value = "[#{_('addpending')}]"


  # remove all tables
  clear: (e) ->
    if not @owner.tables.length
      return
      
    result = confirm _("confirmall") + " ?"
    if not result
      return
      
    @owner.clearTables()


  remove: (e) ->
    titles = @selection.slice 0
    for i in [0 ... titles.length]
      titles[i] = "'#{titles[i].getTitle()}'"
      
    result = confirm _("confirmtable") + " " + titles.join(", ") + "?"
    if not result
      return
      
    sels = @selection.slice 0
    for sel in sels
      @owner.removeTable sel


  edit: (e) ->
    @owner.window.open _("edittable"), @dom.container, @save
    
    title = @selection[0].getTitle()
    @dom.name.value = title
    try
      #throws in ie6
      @dom.comment.value = @selection[0].getComment()
    catch e
      
    # pre-select table name
    @dom.name.focus()
    if OZ.ie
      try
        # throws in ie6
        @dom.name.select()
      catch e
        
    else
      @dom.name.setSelectionRange 0, title.length


  # open keys dialog
  keys: (e) ->
    @owner.keyManager.open @selection[0]


  save: ->
    @selection[0].setTitle @dom.name.value
    @selection[0].setComment @dom.comment.value


  press: (e) ->
    target = OZ.Event.target(e).nodeName.toLowerCase()
    if target is "textarea" or target is "input"
      # not when in form field
      return
    
    if @owner.rowManager.selected
      # do not process keypresses if a row is selected
      return

    if not @selection.length
      # nothing if selection is active
      return

    switch e.keyCode
      when 46
        @remove()
        OZ.Event.prevent e

