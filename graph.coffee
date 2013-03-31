canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 801
canvas.height = 601

drawnLayers = ['nodes', 'arrowLine', 'glow', 'controlPoints']

ctx = canvas.getContext '2d'

selected = null
selectedShape = null
# Object the mouse is hovering on
hovered = null
index = new BBTree()

setShape = (node, shape) ->
  shape.layer = 'nodes'
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

Pool::removeView = Gate::removeView = ->
  arr.removeView() for arr in @out_arrows
  arr.removeView() for arr in @in_arrows
  index.remove @shape
  views.setRemove this
  hovered = null if this is hovered
  select null if this is selected

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

Arrow::makeSegment = ->
  shape = segment 0,0, 0,0, 6
  shape.layer = 'arrowLine'
  shape.owner = this
  index.insert shape
 
Arrow::addView = ->
  # The control points list is a->b->c etc and shapes is the
  # segments a->b, b->c. The shapes list will have 1 less element
  # than control points.
  @controlPoints = [@src, @dst]
  @shapes = [@makeSegment()]
 
  @updateSegments()

  views.push this

Arrow::removeView = ->
  if @controlPoints.length > 2 and
      this is selected and
      selectedShape.layer is 'controlPoints'
    # just remove the control point.
    i = @cpShapes.indexOf selectedShape

    @setSrc null if i is 0
    @setDst null if i is @controlPoints.length - 1

    if i < @shapes.length - 1
      # Normally remove the shape in front of the point
      index.remove @shapes[i]
      @shapes.splice i, 1
    else
      # Remove the shape behind if they delete the last point.
      index.remove @shapes[@shapes.length - 1]
      @shapes.splice -1, 1
    
    if @cpShapes
      index.remove @cpShapes[i]
      @cpShapes.splice i, 1
    @controlPoints.splice i, 1
    @updateSegments()

  else
    index.remove s for s in @shapes
    index.remove c for c in @cpShapes if @cpShapes
    @cpShapes = null
    views.setRemove this
    hovered = null if this is hovered
    select null if this is selected

Arrow::makeControlPoint = (p) ->
  s = circle 0, 0, 4
  s.layer = 'controlPoints'
  s.cachePos p
  s.owner = this
  index.insert s

Arrow::select = ->
  # Spawn control points
  @cpShapes = (@makeControlPoint c.p for c in @controlPoints)

Arrow::deselect = ->
  if @cpShapes then for s in @cpShapes
    index.remove s
  @cpShapes = null

Arrow::moveTo = (p) ->
  return unless selectedShape.layer is 'controlPoints'
  # Move the control point

  i = @cpShapes.indexOf selectedShape

  target = null
  index.pointQuery p, (s) ->
    return unless s.layer is 'nodes'
    target = s.owner if s.pointQuery(mouse)

  hovered = target
  if target
    @controlPoints[i] = target
  else
    @controlPoints[i] = {p, floating:true}

  @setSrc target if i is 0
  @setDst target if i is @controlPoints.length - 1

  @updateSegments()

Arrow::moveBy = (delta) ->
  # moveTo is also called, and it will handle moving individual
  # control points.
  return unless selectedShape.layer is 'arrowLine'

  for c in @controlPoints
    c.p = v.add c.p, delta if c.floating
  @updateSegments()


# Returns 0-1
distBetween = (a, b, x) ->
  delta = v.sub b, a
  v.dot(delta, v.sub x, a) / v.lensq delta

Arrow::doubleClicked = (mouse) ->
  return unless selectedShape.layer is 'arrowLine'

  i = @shapes.indexOf selectedShape
  @controlPoints.splice i+1, 0, {p:mouse, floating:true}
  @cpShapes.splice i+1, 0, @makeControlPoint mouse
  @shapes.splice i+1, 0, @makeSegment()
  @updateSegments()

  selectedShape = @cpShapes[i+1]
  draw()

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

  if @cpShapes then for s,i in @cpShapes
    s.cachePos @controlPoints[i].p

Arrow::strokeArrow = ->
  ctx.beginPath()
  ctx.moveTo @shapes[0].ta.x, @shapes[0].ta.y
  for shape in @shapes
    ctx.lineTo shape.tb.x, shape.tb.y

  last = @shapes[@shapes.length - 1]
  a = last.ta
  b = last.tb
  n = v.normalize v.sub a, b
  left = v.add b, v.mult v.rotate(n, v.forangle Math.PI/4), 6
  right = v.add b, v.mult v.rotate(n, v.forangle -Math.PI/4), 6
  ctx.moveTo left.x, left.y
  ctx.lineTo b.x, b.y
  ctx.lineTo right.x, right.y
  ctx.stroke()

Arrow::draw =
  arrowLine: ->
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'

    if this is hovered or this is selected
      ctx.strokeStyle = if this is selected
        'hsl(192,77%,48%)'
      else
        'orange'

      ctx.lineWidth = 5
      @strokeArrow()
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2
    @strokeArrow()

  glow: ->
    return unless this is selected
    ctx.lineWidth = 10
    ctx.lineCap = 'round'
    ctx.beginPath()
    for cp,i in @controlPoints
      if i is 0
        ctx.moveTo cp.p.x, cp.p.y
      else
        ctx.lineTo cp.p.x, cp.p.y

    ctx.strokeStyle = 'hsla(192,77%,48%,0.2)'
    ctx.stroke()

  controlPoints: ->
    ctx.lineWidth = 1.5
    ctx.strokeStyle = 'red'
    if @cpShapes then for cp in @cpShapes
      ctx.fillStyle = if cp is selectedShape then 'red' else 'white'
      cp.path()
      ctx.fill()
      ctx.stroke()

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
  ctx.beginPath()
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

  ctx.fillStyle = if running then 'hsl(205,74%,97%)' else 'white'
  ctx.fillRect 0, 0, canvas.width, canvas.height
  drawGrid()

  # Collect all the draw functions
  layers = {}
  for v in views
    for layer, drawfn of v.draw
      (layers[layer] ||= []).push [v, drawfn]

  # Call them.
  for layer in drawnLayers
    d.call v for [v, d] in layers[layer]

  # Check we're drawing everything
  console.warn "not drawing #{l}" for l of layers when l not in drawnLayers

setTimeout ->
  draw()
, 50

ui_root = document.getElementById 'ui-root'

options_ui = null

select = (o, s) ->
  if o is selected
    selectedShape = s
  else
    selected?.deselect?()
    selected = o
    selectedShape = s
    selected?.select?()

    if selected
      new_options_ui = makeOptionsUIFor selected
      ui_root.appendChild new_options_ui.el
      setTimeout ->
        new_options_ui.animateIn()
      , 0
      options_ui.animateOut() if options_ui
      options_ui = new_options_ui
    else
      if options_ui
        options_ui.animateOut()
        options_ui = null
  draw()

shapeAt = (mouse) ->
  result = null
  resultLayerId = -1
  index.pointQuery mouse, (s) ->
    return console.error "shape #{s} does not have a layer" unless s.layer
    layerId = drawnLayers.indexOf s.layer
    return console.error "unknown layer #{s.layer}" if layerId is -1

    if resultLayerId < layerId and s.pointQuery(mouse)
      result = s
      resultLayerId = layerId

  result


running = false
saved_state = null
mouse = v 0,0

run_indicator = ui_root.appendChild tag 'div'
style run_indicator,
  position: 'absolute', left: '5px', bottom: '37px'
  border: '5px solid red'
  borderRadius: '10px'
  opacity: '0'
run_indicator.animateIn = -> style run_indicator, opacity: '1'
run_indicator.animateOut = -> style run_indicator, opacity: '0'

toolbar = ui_root.appendChild makeToolbar()
toolbar.appendChild(makePlaceButton('pool')).onclick = -> place 'pool', this
toolbar.appendChild(makePlaceButton('gate')).onclick = -> place 'gate', this
toolbar.appendChild(makePlaceButton('arrow')).onclick = -> place 'arrow', this

place = (type, button) ->
  if ui.state is ui.placing
    ui.pop()
  ui.push ui.placing, type, button

run = ->
  running = true
  hovered = null
  selected = null
  options_ui?.animateOut()
  options_ui = null
  ui.push ui.running
  run_indicator.animateIn()
  draw()
stop = ->
  running = false
  diagram.restore saved_state
  ui.pop()
  run_indicator.animateOut()
  draw()

ui =
  states: []
  state: null
  push: (state, args...) ->
    @states.push @state # save the old state
    @state = state
    @state.enter? args...
  pop: ->
    @state.leave?()
    @state = @states.pop()

ui.default =
  mousemove: (e) ->
    s = shapeAt mouse
    o = s?.owner
    if hovered isnt o
      hovered = o
      draw()
  mousedown: (e) ->
    s = shapeAt mouse
    if s
      ui.push ui.dragging, s.owner, s
      ui.dragging.mousedown? e # Hand the click off.
    else
      select null
  keydown: (e) ->
    switch e.which
      when 32 # space bar
        e.preventDefault()
        saved_state = diagram.state()
        run()
      when 8 # backspace and delete
        e.preventDefault()
        selected?.removeView()
        draw()

ui.dragging =
  enter: (@object, @shape) ->
    @dragPos = mouse
    select @object, @shape
    canvas.style.cursor = 'move'
  mousedown: (e) ->
    @object.doubleClicked? mouse if e.detail is 2
  mousemove: (e) ->
    delta = v.sub mouse, @dragPos
    @dragPos = mouse
    @object.moveBy? delta
    @object.moveTo? mouse
    draw()
  mouseup: (e) ->
    canvas.style.cursor = ''
    ui.pop()

ui.placing =
  enter: (@type, @button) ->
    @button.style.boxShadow = '0px 0px 4px red'
  leave: ->
    @button.style.boxShadow = 'initial'
  mousedown: (e) ->
    if @type is 'pool'
      p = diagram.add new Pool
      p.addView mouse.x, mouse.y
      ui.pop()
      ui.push ui.dragging, p
    else if @type is 'gate'
      p = diagram.add new Gate
      p.addView mouse.x, mouse.y
      ui.pop()
      ui.push ui.dragging, p
    else if @type is 'arrow'
      if s = shapeAt mouse
        src = s.owner
      else
        src = {p:v(mouse.x, mouse.y), floating:true}
      a = diagram.add new Arrow src, {p:v(mouse.x, mouse.y),floating:true}
      a.addView()
      ui.pop()
      select a
      ui.push ui.dragging, a, a.cpShapes[1]
      a
    draw()

ui.running =
  mousedown: (e) ->
    s = shapeAt mouse
    if s
      s.owner.activate?()
      draw()
  keydown: (e) ->
    if e.which is 32
      e.preventDefault()
      stop()

ui.push ui.default

canvas.addEventListener 'mousedown', (e) ->
  mouse = v e.offsetX, e.offsetY
  ui.state.mousedown? e
  return false
window.addEventListener 'mouseup', (e) ->
  ui.state.mouseup? e
  return false
canvas.addEventListener 'mousemove', (e) ->
  mouse = v e.offsetX, e.offsetY
  ui.state.mousemove? e
  return false
window.addEventListener 'keydown', (e) ->
  if document.activeElement.tagName is 'INPUT'
    return
  ui.state.keydown? e
  return false
window.addEventListener 'keyup', (e) ->
  if document.activeElement.tagName is 'INPUT'
    return
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
