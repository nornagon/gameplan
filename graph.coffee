canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 801
canvas.height = 601

ctx = canvas.getContext '2d'

selected = null
# Object the mouse is hovering on
hovered = null
index = new BBTree()

setShape = (node, shape) ->
  shape.cachePos node.p
  index.insert shape

  node.shape = shape
  shape.owner = node

# A list of objects with layered draw functions.
views = []

Pool::addView = (x, y) ->
  @p = v x, y
  setShape this, circle 0, 0, 20
  views.push this

Pool::moveBy = Gate::moveBy = (delta) ->
  @p = v.add @p, delta
  @shape.cachePos @p

  arr.updateSegments() for arr in @out_arrows
  arr.updateSegments() for arr in @in_arrows

Pool::draw = nodes: ->
  if this is hovered or this is selected
    @shape.path()
    ctx.strokeStyle = if this is selected then 'hsl(192,77%,48%)' else 'orange'
    ctx.lineWidth = 8
    ctx.lineJoin = 'round'
    ctx.stroke()
  ctx.fillStyle = 'white'
  ctx.strokeStyle = 'black'
  @shape.draw()

  ctx.font = '30px IsoEur'
  ctx.fillStyle = 'black'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillText @tokens, @p.x, @p.y


Gate::addView = (x, y) ->
  @p = v x, y
  setShape this, poly 0, 0, [
    -20, 0
    0, 20
    20, 0
    0, -20
  ]

  views.push this

Gate::draw = nodes: ->
  if this is hovered or this is selected
    @shape.path()
    ctx.strokeStyle = if this is selected then 'hsl(192,77%,48%)' else 'orange'
    ctx.lineWidth = 8
    ctx.lineJoin = 'round'
    ctx.stroke()
  ctx.fillStyle = 'white'
  @shape.draw()

Arrow::addView = ->
  # The control points list is a->b->c etc and shapes is the
  # segments a->b, b->c. The shapes list will have 1 less element
  # than control points.
  @controlPoints = [@src, @dst]
  shape = segment 0,0, 0,0, 4
  @shapes = [shape]
  index.insert shape
  shape.owner = this
  
  @updateSegments()

  #@spawnControlPoints()

  views.push this

Arrow::spawnControlPoints = ->
  @cpShapes = for c in @controlPoints
    s = rect -4, -4, 8, 8
    s.cachePos c.p
    index.insert s
    s.owner = this
    s

Arrow::updateSegments = ->
  # Could optimise this to only update the needed segment, but I don't
  # expect there to be many segments.
  for shape,i in @shapes
    from = @controlPoints[i]
    to = @controlPoints[i + 1]

    sp = from.p # source position
    dp = to.p # dest position

    shape.a = if from.shape and (q = from.shape.segmentQuery dp, sp)
      dir = v.normalize v.sub(dp, sp)
      v.add v.mult(dir, 6), v.lerp(dp, sp, q.t)
    else
      sp

    shape.b = if to.shape and (q = to.shape.segmentQuery sp, dp)
      dir = v.normalize v.sub sp, dp
      v.add v.mult(dir, 6), v.lerp(sp, dp, q.t)
    else
      dp

    shape.cachePos()

Segment::strokeArrow = ->
  a = @ta
  b = @tb
  ctx.beginPath()
  ctx.moveTo a.x, a.y
  ctx.lineTo b.x, b.y
  n = v.normalize v.sub a, b
  left = v.add b, v.mult v.rotate(n, v.forangle Math.PI/4), 6
  right = v.add b, v.mult v.rotate(n, v.forangle -Math.PI/4), 6
  ctx.moveTo left.x, left.y
  ctx.lineTo b.x, b.y
  ctx.lineTo right.x, right.y
  ctx.stroke()

Arrow::draw =
  arrowline: ->
    for shape in @shapes
      ctx.lineCap = 'round'
      
      if this is hovered
        ctx.strokeStyle = 'orange'
        ctx.lineWidth = 5
        shape.strokeArrow()

      ctx.strokeStyle = 'black'
      ctx.lineWidth = 2
      shape.strokeArrow()

  controlpoints: ->
    ctx.strokeStyle = 'blue'
    if @cpShapes then for cp in @cpShapes
      cp.path()
      ctx.stroke()
      cp.draw()

#index.insert rect 500, 500, 100, 100
#index.insert segment 200, 300, 500, 500, 5

diagram = new Diagram
do ->
  d = diagram
  p1 = d.add new Pool 2
  p1.mode = 'push'
  p1.addView 100, 100
  p2 = d.add new Pool 0
  p2.addView 400, 300
  p2.mode = 'push'

  g = d.add new Gate
  g.addView 300, 300

  a = d.add new Arrow p1, g
  a.addView()
  a = d.add new Arrow g, p2
  a.addView()
  a = d.add new Arrow p2, p1
  a.addView()


drawGrid = ->
  gridSize = 40
  for y in [1...(canvas.height/gridSize)|0]
    ctx.moveTo 0, y*gridSize+0.5
    ctx.lineTo canvas.width-1, y*gridSize+0.5
  for x in [1...(canvas.width/gridSize)|0]
    ctx.moveTo x*gridSize+0.5, 0
    ctx.lineTo x*gridSize+0.5, canvas.height-1
  ctx.strokeStyle = 'hsl(205,77%,76%)'
  ctx.lineWidth = 0.5
  ctx.stroke()
  ctx.beginPath()
  ctx.moveTo 0, 0
  ctx.lineTo canvas.width, 0
  ctx.lineTo canvas.width, canvas.height
  ctx.lineTo 0, canvas.height
  ctx.closePath()
  ctx.lineWidth = 2
  ctx.stroke()
  ctx.lineWidth = 1

draw = ->
  index.reindex()

  ctx.fillStyle = 'white'
  ctx.fillRect 0, 0, canvas.width, canvas.height
  drawGrid()

  # Collect all the draw functions
  layers = {}
  for v in views
    for layer, drawfn of v.draw
      (layers[layer] ||= []).push [v, drawfn]

  # Call them.
  drawnLayers = ['arrowline', 'nodes', 'controlpoints']
  for layer in drawnLayers
    d.call v for [v, d] in layers[layer]

  # Check we're drawing everything
  console.log "not drawing #{l}" for l of layers when l not in drawnLayers

setTimeout ->
  draw()
, 50

select = (o) ->
  selected = o
  draw()

objectAt = (mouse) ->

  result = null
  index.pointQuery mouse, (s) ->
    if s.pointQuery(mouse)
      result = s.owner

  result


running = false
saved_state = null
mouse = v 0,0

ui =
  states: []
  state: null
  push: (state, args...) ->
    @states.push @state # save the old state
    @state = state
    @state.enter? args...
  pop: ->
    @state = @states.pop()

ui.default =
  mousemove: (e) ->
    o = objectAt mouse
    if hovered isnt o
      hovered = o
      draw()
  mousedown: (e) ->
    o = objectAt mouse
    if o and o not instanceof Arrow
      ui.push ui.dragging, o
    else
      select null
  keydown: (e) ->
    if e.which is 32
      e.preventDefault()
      saved_state = diagram.state()
      draw()
      running = true
      hovered = null
      ui.push ui.running

ui.dragging =
  enter: (obj) ->
    @object = obj
    @dragPos = mouse
  mousemove: (e) ->
    delta = v.sub mouse, @dragPos
    @dragPos = mouse
    @object.moveBy delta
    draw()
  mouseup: (e) ->
    select @object
    ui.pop()

ui.running =
  mousedown: (e) ->
    o = objectAt mouse
    if o and o not instanceof Arrow
      o.activate()
      draw()
  keydown: (e) ->
    if e.which is 32
      e.preventDefault()
      running = false
      diagram.restore saved_state
      ui.pop()
      draw()

ui.push ui.default

canvas.addEventListener 'mousedown', (e) ->
  ui.state.mousedown? e
  return false
canvas.addEventListener 'mouseup', (e) ->
  ui.state.mouseup? e
  return false
canvas.addEventListener 'mousemove', (e) ->
  mouse = v e.offsetX, e.offsetY
  ui.state.mousemove? e
  return false
window.addEventListener 'keydown', (e) ->
  ui.state.keydown? e
  return false
window.addEventListener 'keyup', (e) ->
  ui.state.keyup? e
  return false



























































###

dragMousePos = null

mouse = null
canvas.addEventListener 'mousemove', (e) ->
  mouse = v e.offsetX, e.offsetY
  if dragged
    delta = v.sub mouse, dragMousePos
    dragMousePos = mouse

    dragged.moveBy delta

    draw()


  else
    newHover = objectAt mouse

    if hovered != newHover
      hovered = newHover
      draw()

nextMouseUp = null

saved_state = null
window.addEventListener 'keydown', (e) ->
  switch String.fromCharCode e.which
    when " "
      e.preventDefault()
      if running
        diagram.restore saved_state
      else
        saved_state = diagram.state()
      draw()
      running = not running
    when "P"
      break if running
      p = diagram.add new Pool
      p.addView mouse.x, mouse.y
      draw()
      dragged = p
      dragMousePos = mouse
    when "A"
      break if running
      nextMouseUp = ->
        o = objectAt mouse
        a = diagram.add new Arrow o, {p:v(mouse.x,mouse.y), in_arrows:[]}
        a.addView()
        dragged = a
        dragMousePos = mouse
        a.moveBy = (delta) ->
          a.shape.b.x += delta.x
          a.shape.b.y += delta.y
          a.shape.recalcNormal()
          a.shape.cachePos()
        nextMouseUp = try_end = ->
          if o = objectAt mouse
            a.dst = o
            o.in_arrows.push a
            a.shape.b = o.p
            a.shape.recalcNormal()
            a.shape.cachePos()
            draw()
            dragged = null
          else
            nextMouseUp = try_end

canvas.addEventListener 'mousedown', (e) ->
  mouse = v e.offsetX, e.offsetY
  dragged = hover = objectAt mouse
  dragged = null if dragged instanceof Arrow
  if running
    if dragged
      dragged.activate?()
      draw()
    dragged = null
  dragMousePos = mouse

canvas.addEventListener 'mouseup', (e) ->
  if f = nextMouseUp
    nextMouseUp = null
    f()
    return
  dragged = null

###
