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
  

Arrow::addView = ->
  @shape = segment @src.p.x, @src.p.y, @dst.p.x, @dst.p.y, 4
  @shape.cachePos()
  index.insert @shape
  @shape.owner = this


#index.insert rect 500, 500, 100, 100
#index.insert segment 200, 300, 500, 500, 5

do ->
  p1 = new Pool 2
  p1.addView 100, 100
  p2 = new Pool 0
  p2.addView 400, 300

  a = new Arrow p1, p2
  a.addView()


draw = ->
  index.reindex()

  ctx.fillStyle = 'white'
  ctx.fillRect 0, 0, canvas.width, canvas.height
  index.each (s) ->
    ctx.fillStyle = (if hovered is s.owner then 'black' else 'white')
    ctx.strokeStyle = (if hovered is s.owner then 'green' else 'black')
    s.draw()



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

