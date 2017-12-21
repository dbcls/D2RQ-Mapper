class window.SQL.Designer extends SQL.Visual
  
  constructor: ->
    @work_id = 0
    @work_name = ""

    @tables = []
    @relations = []
    @title = document.title

    @relation_color = {}

    @align_table = true

    super()
    new SQL.Toggle(OZ.$("toggle"))
    
    @dom.container = OZ.$("area")
    @minSize = [
      @dom.container.offsetWidth
      @dom.container.offsetHeight
    ]
    @width = @minSize[0]
    @height = @minSize[1]
    
    @typeIndex = false
    @fkTypeFor = false

    @vector = @getOption("vector") and document.createElementNS
    if @vector
      @svgNS = "http://www.w3.org/2000/svg"
      @dom.svg = document.createElementNS @svgNS, "svg"
      @dom.container.appendChild @dom.svg

    @flag = 2
    @requestLanguage()
    @requestDB()


  # update area size
  sync: ->
    w = @minSize[0];
    h = @minSize[0];
    for t in @tables
      w = Math.max(w, t.x + t.width)
      h = Math.max(h, t.y + t.height)
    
    @width = w
    @height = h
    @map.sync()

    if @vector
      @dom.svg.setAttribute "width", @width
      @dom.svg.setAttribute "height", @height

  # get locale file
  requestLanguage: ->
    lang = @getOption "locale"
    bp = @getOption "staticpath"
    url = "#{bp}locale/#{lang}.xml"
    OZ.Request url, @languageResponse.bind(this), {method: "get", xml: true}


  languageResponse: (xmlDoc) ->
    if xmlDoc
      strings = xmlDoc.getElementsByTagName "string"
      for i in [0 ... strings.length]
        n = strings[i].getAttribute "name"
        v = strings[i].firstChild.nodeValue
        window.LOCALE[n] = v

    @flag--
    if not @flag
      @init2()


  # get datatypes file
  requestDB: ->
    db = @getOption "db"
    bp = @getOption "staticpath"
    url = "#{bp}db/#{db}/datatypes.xml"
    OZ.Request url, @dbResponse.bind(this), {method:"get", xml:true}


  dbResponse: (xmlDoc) ->
    if xmlDoc
      window.DATATYPES = xmlDoc.documentElement

    @flag--
    if not @flag
      @init2()

  # secondary init, after locale & datatypes were retrieved
  init2: ->
    @map = new SQL.Map(this)
    @rubberband = new SQL.Rubberband(this)
    @tableManager = new SQL.TableManager(this)
    @rowManager = new SQL.RowManager(this)
    @keyManager = new SQL.KeyManager(this)
    @io = new SQL.IO(this)
    @options = new SQL.Options(this)
    @window = new SQL.Window(this)

    @sync()
    
    #OZ.$("docs").value = _("docs");
    OZ.$("menu").value = _("menu")

    url = window.location.href

    #var r = url.match(/keyword=([^&]+)/)
    #if r
    #  keyword = r[1]
    #  @io.serverload(false, keyword)

    keyword = url.slice(url.lastIndexOf("/") + 1)
    @work_id = keyword
    @io.serverload false, keyword

    document.body.style.visibility = "visible"

  # find max zIndex
  getMaxZ: ->
    max = 0
    for table in @tables
      z = table.getZ()
      if z > max
        max = z
    
    OZ.$("controls").style.zIndex = max + 5

    max


  addTable: (name, x, y) ->
    max = @getMaxZ();
    t = new SQL.Table(this, name, x, y, max + 1)
    @tables.push t
    @dom.container.appendChild t.dom.container

    t


  removeTable: (t) ->
    @tableManager.select false
    @rowManager.select false
    idx = @tables.indexOf t
    if idx is -1
      return

    t.destroy()
    @tables.splice idx, 1


  addRelation: (row1, row2, join_id) ->
    color = "#000";
    if @relation_color[join_id]
      color = @relation_color[join_id]
    else
      SQL.Relation._counter++
      colorIndex = SQL.Relation._counter - 1
      color = CONFIG.RELATION_COLORS[colorIndex % CONFIG.RELATION_COLORS.length]
      @relation_color[join_id] = color

    r = new SQL.Relation(this, row1, row2, join_id, color)
    @relations.push r

    r


  removeRelation: (r) ->
    idx = @relations.indexOf r
    if idx is -1
      return

    r.destroy()
    @relations.splice idx, 1


  getCookie: ->
    c = document.cookie
    obj = {}
    parts = c.split ";"
    for part in parts
      r = part.match /wwwsqldesigner=({.*?})/
      if r
        obj = eval "(#{r[1]})"

    obj


  setCookie: (obj) ->
    arr = []
    for p in obj
      arr.push "#{p}:'#{obj[p]}'"

    str = "{#{arr.join(',')}}"
    document.cookie = "wwwsqldesigner=#{str}; path=/"


  getOption: (name) ->
    c = @getCookie()
    if name in c
      return c[name]

    # defaults
    switch name
      when "locale"
        return CONFIG.DEFAULT_LOCALE
      when "db"
        return CONFIG.DEFAULT_DB
      when "staticpath"
        return CONFIG.STATIC_PATH or ""
      when "xhrpath"
        return CONFIG.XHR_PATH or ""
      when "snap"
        return 0
      when "showsize"
        return 0
      when "showtype"
        return 0
      when "pattern"
        return "%R_%T"
      when "hide"
        return false
      when "vector"
        return true
      else
        return null


  setOption: (name, value) ->
    obj = @getCookie()
    obj[name] = value
    @setCookie(obj)


  # raise a table
  raise: (table) ->
    old = table.getZ()
    max = @getMaxZ()
    table.setZ(max)
    for t in @tables
      if t is table
        continue

      if t.getZ() > old
        t.setZ(t.getZ() - 1)

    m = table.dom.mini
    m.parentNode.appendChild m


  clearTables: ->
    while @tables.length
      @removeTable @tables[0]

    @setTitle false


  alignTables: ->
    win = OZ.DOM.win()
    avail = win[0] - OZ.$("bar").offsetWidth
    x = 10
    y = 10
    max = 0
    
    @tables.sort( (a, b) ->
      b.getRelations().length - a.getRelations().length
    )

    for t in @tables
      w = t.dom.container.offsetWidth;
      h = t.dom.container.offsetHeight;
      if x + w > avail
        x = 10
        y += 10 + max
        max = 0

      t.moveTo x, y
      x += 10 + w;
      if h > max
        max = h

    @sync();

  # find row specified as table(row)
  findNamedTable: (name) ->
    for table in @tables
      if table.getTitle() is name
        return table


  toJSON: ->
    obj = [];

    for i in [0 ... @tables.length]
      obj[i] = {
        id: @tables[i].class_map_id
        enable: @tables[i].enable
        x: @tables[i].x
        y: @tables[i].y
      }

    JSON.stringify obj


  toXML: ->
    xml = '<?xml version="1.0" encoding="utf-8" ?>\n'
    xml += '<!-- SQL XML created by WWW SQL Designer, https://github.com/ondras/wwwsqldesigner/ -->\n'
    xml += '<!-- Active URL: ' + location.href + ' -->\n'
    xml += '<sql>\n'
    
    # serialize datatypes
    ###
    if window.XMLSerializer
      s = new XMLSerializer()
      xml += s.serializeToString(window.DATATYPES)
    else if window.DATATYPES.xml
      xml += window.DATATYPES.xml
    else 
      alert(_("errorxml") + ': ' + e.message)
    ###

    # work
    xml += '<work id="' + @work_id + '" name="' + @work_name + '">' + '</work>'

    # tables
    for table in @tables
      xml += table.toXML()

    xml += "</sql>\n";

    xml;


  fromXML: (node) ->
    @clearTables()
    types = node.getElementsByTagName "datatypes"
    if types.length
      window.DATATYPES = types[0]

    # work
    work = node.getElementsByTagName("work")[0]
    @work_id = work.getAttribute "id"
    @work_name = work.getAttribute "name"

    # tables
    tables = node.getElementsByTagName "table"
    for table in tables
      t = @addTable "", 0, 0
      t.fromXML table

    # ff one-pixel shift hack
    for table in @tables
      table.select()
      table.deselect()

    # relations
    rs = node.getElementsByTagName "relation"
    for rel in rs
      tname = rel.getAttribute "table"
      rname = rel.getAttribute "row"
      join_id = rel.getAttribute "id"
	
      t1 = @findNamedTable tname
      if not t1
        continue

      r1 = t1.findNamedRow rname
      if not r1
        continue
      
      tname = rel.parentNode.parentNode.getAttribute "name"
      rname = rel.parentNode.getAttribute "name"
      t2 = @findNamedTable tname
      if not t2
        continue
      r2 = t2.findNamedRow rname
      if not r2
        continue

      @addRelation(r1, r2, join_id)
    
    @sync()

    if @align_table
      @alignTables()
      #@io.serversave null, @work_id
      json = @toJSON()
      url = "/works/#{@work_id}/er_data"
      $.post(url, { json: json, echo_message: false });


  setTitle: (t) ->
    #document.title = @title + (t ? " - " + t : "")


  removeSelection: ->
    if window.getSelection
      sel = window.getSelection()
    else
      sel = document.selection

    if not sel
      return

    if sel.empty
      sel.empty()

    if sel.removeAllRanges
      sel.removeAllRanges()


  getTypeIndex: (label) ->
    if not @typeIndex
      @typeIndex = {}
      types = window.DATATYPES.getElementsByTagName "type"
      for i in [0 ... types]
        l = types[i].getAttribute "label"
        if l
          @typeIndex[l] = i

    @typeIndex[label]


  getFKTypeFor: (typeIndex) ->
    if not @fkTypeFor
      @fkTypeFor = {}
      types = window.DATATYPES.getElementsByTagName "type"
      for i in [0 ... types.length]
        @fkTypeFor[i] = i
        fk = types[i].getAttribute "fk"
        if fk
          @fkTypeFor[i] = @getTypeIndex fk

    @fkTypeFor[typeIndex]
