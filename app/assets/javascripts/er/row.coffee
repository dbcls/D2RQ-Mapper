# table row ( = db column)

class window.SQL.Row extends SQL.Visual

  constructor: (owner, title, data) ->
    @owner = owner
    @relations = []
    @keys = []
    @selected = false
    @expanded = false

    super()
    
    @data.type = 0
    @data.size = ""
    @data.def = null
    @data.nll = true
    @data.ai = false
    @data.comment = ""

    if data
      @update data

    @setTitle title


  _build: ->
    # @dom.container = OZ.DOM.elm("tbody");
    @dom.container = OZ.DOM.elm "tbody", {className: "sqldesigner-column-row"}
    
    @dom.content = OZ.DOM.elm "tr"
    # @dom.selected = OZ.DOM.elm("div", {className: "selected",innerHTML: "&raquo;&nbsp;"});
    # @dom.title = OZ.DOM.elm("div", {className: "title"});
    @dom.title = OZ.DOM.elm "div"
    td1 = OZ.DOM.elm "td"
    # var td2 = OZ.DOM.elm("td", {className:"typehint"});
    # @dom.typehint = td2;
    @dom.rdfbtn = OZ.DOM.elm "td", {className: "er-column-rdf-btn btn btn-rdf"}

    OZ.DOM.append(
      [@dom.container, @dom.content],
      [@dom.content, td1, @dom.rdfbtn],
      # [td1, @dom.selected, @dom.title]
      [td1, @dom.title]
    )
    
    @enter = @enter.bind this
    @changeComment = @changeComment.bind this

    # OZ.Event.add(@dom.container, "click",@click.bind(this));
    OZ.Event.add @dom.container, "dblclick", @dblclick.bind(this)
    OZ.Event.add @dom.rdfbtn,    "click",    @rdfbtn_click.bind(this)
    
    $(@dom.container).droppable {
      accept: ".rdf-property"
      onDragEnter: (event, source) ->
      onDragOver: (event, source) ->
      onDragLeave: (event, source) ->
      onDrop: (event, source) ->
        property_bridge_id = $(event.target).attr "data-pbid"
        property = $(source).text()
        $.getScript "/ajax/er/predicate_object_map_dialog/#{property_bridge_id}?property=#{property}"
        $("#staticModalPredicateObjectMap").modal()
    }


  select: ->
    if @selected
      return
    @selected = true
    @redraw()


  deselect: ->
    if not @selected
      return
    @selected = false
    @redraw()
    @collapse()


  setTitle: (title) ->
    old = @getTitle()
    for r in @relations
      if r.row1 isnt this
        continue

      tt = r.row2.getTitle().replace(new RegExp(old, "g"), title)
      if tt isnt r.row2.getTitle()
        r.row2.setTitle tt
    
    $(@dom.container).attr "id", @owner.getTitle() + "-" + title
    $(@dom.container).attr "data-rowname", title
    super(title)


  # clicked on row
  click: (e) ->
    SQL.publish "rowclick", this
    @owner.owner.rowManager.select this


  # dblclicked on row
  dblclick0: (e) ->
    OZ.Event.prevent e
    OZ.Event.stop e
    @expand()

  dblclick: (e) ->
    OZ.Event.prevent e
    OZ.Event.stop e
    property_bridge_id = $(@dom.container).attr "data-pbid"
    $.getScript "/ajax/er/predicate_object_map_dialog/#{property_bridge_id}/edit"


  rdfbtn_click: (e) ->
    OZ.Event.stop e
    rdfbtn = OZ.Event.target e
    tbody = $(rdfbtn).closest "tbody"
    row_name = $(tbody).attr "data-rowname"
    property_bridge_id = $(tbody).attr "data-pbid"

    row = @owner.findNamedRow row_name

    $.ajax {
      url: "/property_bridges/#{property_bridge_id}/toggle_enable"
      type: "POST"
      success: (data) ->
        row.enable = not row.enable
        if row.enable
          $(tbody).removeClass "disable"
          $(rdfbtn).removeClass("btn-default").removeClass("btn-rdf-enable").addClass("btn-primary").addClass("btn-rdf-disable")
        else
          $(tbody).addClass "disable"
          $(rdfbtn).removeClass("btn-primary").removeClass("btn-rdf-disable").addClass("btn-default").addClass("btn-rdf-enable")
      error: (XMLHttpRequest, textStatus, errorThrown) ->
        alert "Error !"
    }


  # update subset of row data
  update: (data) ->
    des = SQL.Designer
    if data.nll and data.def and data.def.match /^null$/i
      data.def = null
    
    for key, value of data
      @data[key] = value

    if not @data.nll and @data.def is null
      @data.def = ""

    elm = @getDataType()
    for r in @relations
      if r.row1 is this
        r.row2.update {type: des.getFKTypeFor(@data.type), size: @data.size}

    @redraw()


  # shift up
  up: ->
    r = @owner.rows
    idx = r.indexOf this
    if not idx
      return
    r[idx-1].dom.container.parentNode.insertBefore @dom.container, r[idx-1].dom.container
    r.splice idx, 1
    r.splice idx-1, 0, this
    @redraw()


  # shift down
  down: ->
    r = @owner.rows
    idx = r.indexOf this
    if idx+1 is @owner.rows.length
      return
    r[idx].dom.container.parentNode.insertBefore @dom.container, r[idx+1].dom.container.nextSibling
    r.splice idx, 1
    r.splice idx+1, 0, this
    @redraw()


  buildEdit: ->
    OZ.DOM.clear @dom.container
    
    elms = []
    @dom.name = OZ.DOM.elm "input"
    @dom.name.type = "text"
    elms.push ["name", @dom.name]
    OZ.Event.add @dom.name, "keypress", @enter

    @dom.type = @buildTypeSelect @data.type
    elms.push ["type",@dom.type]

    @dom.size = OZ.DOM.elm "input"
    @dom.size.type = "text"
    elms.push ["size", @dom.size]

    @dom.def = OZ.DOM.elm "input"
    @dom.def.type = "text"
    elms.push ["def", @dom.def]

    @dom.ai = OZ.DOM.elm "input"
    @dom.ai.type = "checkbox"
    elms.push ["ai", @dom.ai]

    @dom.nll = OZ.DOM.elm "input"
    @dom.nll.type = "checkbox"
    elms.push ["null", @dom.nll]
    
    @dom.comment = OZ.DOM.elm "span", {className: "comment"}
    @dom.comment.innerHTML = ""
    @dom.comment.appendChild document.createTextNode(@data.comment)

    @dom.commentbtn = OZ.DOM.elm "input"
    @dom.commentbtn.type = "button"
    @dom.commentbtn.value = _("comment")
    
    OZ.Event.add @dom.commentbtn, "click", @changeComment

    for row in elems
      tr = OZ.DOM.elm "tr"
      td1 = OZ.DOM.elm "td"
      td2 = OZ.DOM.elm "td"
      l = OZ.DOM.text _(row[0]) + ": "
      OZ.DOM.append [tr, td1, td2], [td1, l], [td2, row[1]]
	
      @dom.container.appendChild tr
    
    tr = OZ.DOM.elm "tr"
    td1 = OZ.DOM.elm "td"
    td2 = OZ.DOM.elm "td"
    OZ.DOM.append [tr, td1, td2], [td1, @dom.comment], [td2, @dom.commentbtn]

    @dom.container.appendChild tr


  changeComment: (e) ->
    c = prompt _("commenttext"), @data.comment
    if c is null
      return
    @data.comment = c
    @dom.comment.innerHTML = ""
    @dom.comment.appendChild document.createTextNode(@data.comment)


  expand: ->
    if @expanded
      return
    @expanded = true
    @buildEdit()
    @load()
    @redraw()
    @dom.name.focus()
    @dom.name.select()


  collapse: ->
    if not @expanded
      return
    @expanded = false

    data = {
      type: @dom.type.selectedIndex
      def:  @dom.def.value
      size: @dom.size.value
      nll:  @dom.nll.checked
      ai:   @dom.ai.checked
    }
    
    OZ.DOM.clear @dom.container
    @dom.container.appendChild @dom.content

    @update data
    @setTitle @dom.name.value


  # put data to expanded form
  load: ->
    @dom.name.value = @getTitle()
    def = @data.def
    if def is null
      def = "NULL"
    
    @dom.def.value = def
    @dom.size.value = @data.size
    @dom.nll.checked = @data.nll
    @dom.ai.checked = @data.ai


  redraw: ->
    # var color = @getColor();
    # @dom.container.style.backgroundColor = color;
    # OZ.DOM.removeClass(@dom.title, "primary");
    # OZ.DOM.removeClass(@dom.title, "key");
    # if (@isPrimary()) { OZ.DOM.addClass(@dom.title, "primary"); }
    # if (@isKey()) { OZ.DOM.addClass(@dom.title, "key"); }
    # @dom.selected.style.display = (@selected ? "" : "none");
    @dom.container.title = @data.comment

    ###
    var typehint = [];
    if (@owner.owner.getOption("showtype")) {
      var elm = @getDataType();
      typehint.push(elm.getAttribute("sql"));
    }
    
    if (@owner.owner.getOption("showsize") && @data.size) {
      typehint.push("(" + @data.size + ")");
    }
    ###

    # for D2RQ Mapper
    $(@dom.container).attr "data-pbid", @property_bridge_id
    if @enable
      $(@dom.container).removeClass "disable"
      $(@dom.rdfbtn).removeClass("btn-default").removeClass("btn-rdf-enable").addClass("btn-primary").addClass("btn-rdf-disable")
    else
      $(@dom.container).addClass "disable"
      $(@dom.rdfbtn).removeClass("btn-primary").removeClass("btn-rdf-disable").addClass("btn-default").addClass("btn-rdf-enable");

    # @dom.typehint.innerHTML = typehint.join(" ");
    @owner.redraw()
    @owner.owner.rowManager.redraw()


  addRelation: (r) ->
    @relations.push r


  removeRelation: (r) ->
    idx = @relations.indexOf r
    if idx is -1
      return
    @relations.splice idx, 1


  addKey: (k) ->
    @keys.push k
    @redraw()


  removeKey: (k) ->
    idx = @keys.indexOf k
    if idx is -1
      return
    @keys.splice idx, 1
    @redraw()


  getDataType: ->
    type = @data.type
    elm = DATATYPES.getElementsByTagName("type")[type]

    elm


  getColor: ->
    elm = @getDataType()
    g = @getDataType().parentNode
    
    elm.getAttribute("color") or g.getAttribute("color") or "#fff"


  # build selectbox with avail datatypes */
  buildTypeSelect: (id) ->
    s = OZ.DOM.elm "select"
    gs = DATATYPES.getElementsByTagName "group"
    for g in gs
      og = OZ.DOM.elm "optgroup"
      # og.style.backgroundColor = g.getAttribute("color") || "#fff";
      og.label = g.getAttribute "label"
      s.appendChild og
      ts = g.getElementsByTagName "type"
      for t in ts 
        o = OZ.DOM.elm "option"
        if t.getAttribute "color"
          o.style.backgroundColor = t.getAttribute "color"

        if t.getAttribute "note"
          o.title = t.getAttribute "note"

        o.innerHTML = t.getAttribute "label"
        og.appendChild o

    s.selectedIndex = id
    
    s


  destroy: ->
    #SQL.Visual.prototype.destroy.apply(this);
    super()
    while @relations.length
      @owner.owner.removeRelation @relations[0]

    for key in @keys
      key.removeRow this


  toXML: ->
    xml = ""
    
    t = @getTitle().replace(/"/g, "&quot;")
    if @data.nll
      nn = "1"
    else
      nn = "0"

    if @data.ai
      ai = "1"
    else
      ai = "0"

    #xml += '<row name="'+t+'" null="'+nn+'" autoincrement="'+ai+'">\n';
    xml += '<row name="' + t + '" id="' + @property_bridge_id + '" enable="' + @enable + '">\n';

    elm = @getDataType()
    t = elm.getAttribute "sql"
    if @data.size.length
      t += "(#{@data.size})"
    xml += "<datatype>#{t}</datatype>\n"
    
    if @data.def or @data.def is null
      q = elm.getAttribute "quote"
      d = @data.def
      if d is null
        d = "NULL"
      else if d isnt "CURRENT_TIMESTAMP"
        d = q + d + q;

      xml += "<default>#{SQL.escape(d)}</default>"

    for r in @relations
      if r.row2 isnt this
        continue

      xml += '<relation table="' + r.row1.owner.getTitle() + '" row="' + r.row1.getTitle() + '" />\n'

    if @data.comment
      xml += "<comment>#{SQL.escape(@data.comment)}</comment>\n"
    
    xml += "</row>\n"
    
    xml


  fromXML: (node) ->
    name = node.getAttribute "name"
    name = name.replace /^col_/, ""
    
    property_bridge_id = node.getAttribute "id"
    enable = node.getAttribute "enable"
    if enable is "true"
      enable = true
    else
      enable = false

    @property_bridge_id = property_bridge_id
    @enable = enable

    obj = {
      type: 0
      size: ""
    }
    #obj.nll = (node.getAttribute("null") == "1");
    #obj.ai = (node.getAttribute("autoincrement") == "1");

    ###
    var cs = node.getElementsByTagName("comment");
    if (cs.length && cs[0].firstChild) {
      obj.comment = cs[0].firstChild.nodeValue;
    }
    ###

    ###
    var d = node.getElementsByTagName("datatype");
    if (d.length && d[0].firstChild) {
      var s = d[0].firstChild.nodeValue;
      var r = s.match(/^([^\(]+)(\((.*)\))?.*$/);
      var type = r[1];
      if (r[3]) { obj.size = r[3]; }
      var types = window.DATATYPES.getElementsByTagName("type");
      for (var i=0;i<types.length;i++) {
        var sql = types[i].getAttribute("sql");
        var re = types[i].getAttribute("re");
        if (sql == type || (re && new RegExp(re).exec(type)) ) { obj.type = i; }
      }
    }
    ###

    ###
    var elm = DATATYPES.getElementsByTagName("type")[obj.type];
    var d = node.getElementsByTagName("default");
    if (d.length && d[0].firstChild) { 
      var def = d[0].firstChild.nodeValue;
      obj.def = def;
      var q = elm.getAttribute("quote");
      if (q) {
        var re = new RegExp("^" + q + "(.*)" + q + "$");
        var r = def.match(re);
        if (r) {
          obj.def = r[1];
        }
      }
    }
    ###

    @update obj
    @setTitle name


  isPrimary: ->
    for k in @keys
      if k.getType() is "PRIMARY"
        return true

    false


  isUnique: ->
    for k in @keys
      t = k.getType()
      if t is "PRIMARY" or t is "UNIQUE"
        return true
    
    false


  isKey: ->
    @keys.length > 0


  enter: (e) ->
    if e.keyCode is 13
      @collapse()

