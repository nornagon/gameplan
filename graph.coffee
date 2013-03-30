canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 801
canvas.height = 601

ctx = canvas.getContext '2d'

# Object the mouse is currently dragging
dragged = null
# Object the mouse is hovering on
hovered = null
index = new BBTree()

setShape = (node, shape) ->
  shape.cachePos node.p
  index.insert shape

  node.shape = shape
  shape.owner = node

Pool::addView = (x, y) ->
  @p = v x, y
  setShape this, circle 0, 0, 20

Pool::type = 'pool'

Pool::z = 1

Pool::moveBy = Gate::moveBy = (delta) ->
  @p = v.add @p, delta
  @shape.cachePos @p

  for arr in @out_arrows
    arr.shape.a = @p
    arr.shape.recalcNormal()
    arr.shape.cachePos()
  for arr in @in_arrows
    arr.shape.b = @p
    arr.shape.recalcNormal()
    arr.shape.cachePos()
  
Pool::draw = ->
  if this is hovered
    @shape.path()
    ctx.strokeStyle = 'orange'
    ctx.lineWidth = 8
    ctx.lineJoin = 'round'
    ctx.stroke()
  ctx.fillStyle = 'white'
  ctx.strokeStyle = 'black'
  @shape.draw()

  ctx.font = '20px sans-serif'
  ctx.fillStyle = 'black'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillText @tokens, @p.x, @p.y

Arrow::addView = ->
  @shape = segment @src.p.x, @src.p.y, @dst.p.x, @dst.p.y, 2
  @shape.cachePos()
  index.insert @shape
  @shape.owner = this

Arrow::draw = ->
  ctx.strokeStyle = 'red'
  a = @shape.ta
  b = @shape.tb
  if @src.shape
    q = @src.shape.segmentQuery @shape.tb, @shape.ta
    if q
      n = v.normalize v.sub(@shape.tb, @shape.ta)
      a = v.add v.mult(n, 6), v.lerp(@shape.tb, @shape.ta, q.t)
  if @dst.shape
    q = @dst.shape.segmentQuery @shape.ta, @shape.tb
    if q
      n = v.normalize v.sub(@shape.ta, @shape.tb)
      b = v.add v.mult(n, 6), v.lerp(@shape.ta, @shape.tb, q.t)

  ctx.lineCap = 'round'
  ctx.lineWidth = 2
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

Arrow::z = 0

Gate::addView = (x, y) ->
  @p = v x, y
  setShape this, poly 0, 0, [
    -20, 0
    0, 20
    20, 0
    0, -20
  ]

Gate::draw = ->
  if this is hovered
    @shape.path()
    ctx.strokeStyle = 'orange'
    ctx.lineWidth = 8
    ctx.lineJoin = 'round'
    ctx.stroke()
  ctx.fillStyle = 'white'
  @shape.draw()

Gate::z = 1

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

  nodes = []
  index.each (s) -> nodes.push s.owner
  nodes.sort (a, b) -> (a.z ? 0) - (b.z ? 0)

  n.draw() for n in nodes



draw()


objectAt = (mouse) ->

  result = null
  index.pointQuery mouse, (s) ->
    if s.pointQuery(mouse) and s.owner not instanceof Arrow
      result = s.owner

  result

dragMousePos = null

canvas.addEventListener 'mousemove', (e) ->
  mouse = v e.offsetX, e.offsetY
  if dragged
    return if dragged instanceof Arrow

    delta = v.sub mouse, dragMousePos
    dragMousePos = mouse

    dragged.moveBy delta

    draw()


  else
    newHover = objectAt mouse

    if hovered != newHover
      hovered = newHover
      draw()

saved_state = null
running = false
window.addEventListener 'keydown', (e) ->
  if e.which is 32
    e.preventDefault()
    if running
      diagram.restore saved_state
    else
      saved_state = diagram.state()
    draw()
    running = not running

canvas.addEventListener 'mousedown', (e) ->
  mouse = v e.offsetX, e.offsetY
  dragged = hover = objectAt mouse
  if running
    if dragged
      dragged.activate?()
      draw()
    dragged = null
  else
  dragMousePos = mouse

canvas.addEventListener 'mouseup', (e) ->
  dragged = null

