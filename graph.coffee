canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 800
canvas.height = 600

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
  setShape this, circle 0, 0, 30

Pool::type = 'pool'

Pool::z = 1

Pool::moveBy = (delta) ->
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
  ctx.fillStyle = (if this is hovered then 'blue' else 'white')
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
  @shape.draw()

Arrow::z = 0

#index.insert rect 500, 500, 100, 100
#index.insert segment 200, 300, 500, 500, 5

do ->
  d = new Diagram
  p1 = d.add new Pool 2
  p1.addView 100, 100
  p2 = d.add new Pool 0
  p2.addView 400, 300

  a = d.add new Arrow p1, p2
  a.addView()


draw = ->
  index.reindex()

  ctx.fillStyle = 'white'
  ctx.fillRect 0, 0, canvas.width, canvas.height

  nodes = []
  index.each (s) -> nodes.push s.owner
  nodes.sort (a, b) -> (+a.z) - (+b.z)

  n.draw() for n in nodes



draw()


objectAt = (mouse) ->

  result = null
  index.pointQuery mouse, (s) ->
    if s.pointQuery mouse
      result = s.owner

  result

dragMousePos = null

canvas.addEventListener 'mousemove', (e) ->
  mouse = v e.offsetX, e.offsetY
  if dragged
    return unless dragged.type is 'pool' # for now...

    delta = v.sub mouse, dragMousePos
    dragMousePos = mouse

    dragged.moveBy delta

    draw()


  else
    newHover = objectAt mouse

    if hovered != newHover
      hovered = newHover
      draw()


canvas.addEventListener 'mousedown', (e) ->
  mouse = v e.offsetX, e.offsetY
  dragged = hover = objectAt mouse
  dragMousePos = mouse

canvas.addEventListener 'mouseup', (e) ->
  dragged = null

