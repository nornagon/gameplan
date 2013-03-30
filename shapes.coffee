unless window?
  v = require './vect'
min = Math.min
max = Math.max

circleSegmentQuery = (shape, center, r, a, b, info) ->
  # offset the line to be relative to the circle
  a = v.sub a, center
  b = v.sub b, center
  
  qa = v.dot(a, a) - 2*v.dot(a, b) + v.dot(b, b)
  qb = -2*v.dot(a, a) + 2*v.dot(a, b)
  qc = v.dot(a, a) - r*r
  
  det = qb*qb - 4*qa*qc
  
  if det >= 0
    t = (-qb - Math.sqrt(det))/(2*qa)
    if 0 <= t and t <= 1
      return {shape, t, n:v.normalize(v.lerp(a, b, t))}

exports.circle = (x, y, radius) ->
  throw new error 'need an x' unless typeof x is 'number'
  throw new error 'need a y' unless typeof y is 'number'
  throw new error 'need a radius' unless typeof radius is 'number'

  c: v(x,y) # center
  tc: null # transformed center
  r: radius # radius
  type: 'circle'

  cachePos: (tpos, trot) ->
    c = @c
    c = v.rotate c, trot if trot
    c = v.add tpos, c if tpos
    @tc = c
    #@tc = v.add tpos, v.rotate(@c, trot)
    @bb_l = @tc.x - @r
    @bb_r = @tc.x + @r
    @bb_b = @tc.y - @r
    @bb_t = @tc.y + @r
    this

  draw: ->
    #ctx.fillStyle = @owner?.color or 'green'
    #ctx.strokeStyle = 'black'
    ctx.lineWidth = 2

    ctx.beginPath()
    ctx.arc @tc.x, @tc.y, @r, 0, 2*Math.PI, false
    ctx.fill()
    ctx.stroke()

  # Test if a point lies within a shape.
  pointQuery: (p) ->
    delta = v.sub p, @tc
    distsq = v.lensq delta
    
    if distsq < @r * @r
      dist = Math.sqrt distsq
      shape: this
      d: @r - dist
      n: v.mult delta, 1/dist

  segmentQuery: (a, b) ->
    circleSegmentQuery this, @tc, @r, a, b

  toJSON: -> {@type, @c, @r}

bbContainsVect2 = (l, b, r, t, v) -> l <= v.x && r >= v.x && b <= v.y && t >= v.y

# Line segment from a to b with width r
exports.segment = (x1, y1, x2, y2, r) ->
  a = v x1, y1
  b = v x2, y2

  a: a
  b: b
  r: r
  n: v.perp v.normalize v.sub b, a
  recalcNormal: ->
    @n = v.perp v.normalize v.sub @b, @a
  type: 'segment'
  cachePos: (tpos, trot) ->
    tpos ?= v.zero

    @ta = v.add tpos, (if trot then v.rotate @a, trot else @a)
    @tb = v.add tpos, (if trot then v.rotate @b, trot else @b)
    @tn = if trot then v.rotate @n, trot else @n

    # Update the bounding box
    if @ta.x < @tb.x
      l = @ta.x
      r = @tb.x
    else
      l = @tb.x
      r = @ta.x

    if @ta.y < @tb.y
      b = @ta.y
      t = @tb.y
    else
      b = @tb.y
      t = @ta.y

    @bb_l = l - @r
    @bb_b = b - @r
    @bb_r = r + @r
    @bb_t = t + @r
    this

  draw: ->
    ctx.lineCap = 'round'
    ctx.lineWidth = max 1, @r * 2
    #ctx.strokeStyle = @owner.color or 'black'
    ctx.beginPath()
    ctx.moveTo @ta.x, @ta.y
    ctx.lineTo @tb.x, @tb.y
    ctx.stroke()

  pointQuery: (p) ->
    return unless bbContainsVect2 @bb_l, @bb_b, @bb_r, @bb_t, p
  
    a = @ta
    b = @tb
    
    seg_delta = v.sub b, a
    closest_t = v.clamp01 v.dot(seg_delta, v.sub(p, a))/v.lensq(seg_delta)
    closest = v.add a, v.mult(seg_delta, closest_t)

    delta = v.sub p, closest
    distsq = v.lensq delta

    if distsq < @r*@r
      dist = Math.sqrt distsq
      shape: this
      d: @r - dist
      n: v.mult(delta, 1/dist)

  segmentQuery: (a, b) ->
    d = v.dot v.sub(this.ta, a), @tn
    
    flipped_n = if d > 0 then v.neg(@tn) else @tn
    n_offset = v.sub v.mult(flipped_n, @r), a
    
    seg_a = v.add @ta, n_offset
    seg_b = v.add @tb, n_offset
    delta = v.sub b, a
    
    if v.cross(delta, seg_a)*v.cross(delta, seg_b) <= 0
      d_offset = d + if d > 0 then -@r else @r
      ad = -d_offset
      bd = v.dot(delta, @tn) - d_offset
      
      if ad*bd < 0
        {shape:this, t:ad/(ad - bd), n:flipped_n}

    else if @r != 0
      info1 = circleSegmentQuery this, this.ta, this.r, a, b
      info2 = circleSegmentQuery this, this.tb, this.r, a, b
      
      if info1
        if info2 && info2.t < info1.t then info2 else info1
      else
        return info2


Axis = (@n, @d) ->

# Check that a set of vertexes is convex and has a clockwise winding.
polyValidate = (verts) ->
  len = verts.length
  for i in [0...len] by 2
    x1 = verts[i]
    y1 = verts[i+1]
    x2 = verts[(i+2)%len]
    y2 = verts[(i+3)%len]
    x3 = verts[(i+4)%len]
    y3 = verts[(i+5)%len]
    
    return false if vcross2(x2 - x1, y2 - y1, x3 - x2, y3 - y2) > 0
  
  true


setAxes = (poly) ->
  verts = poly.verts
  len = verts.length
  numVerts = len >> 1

  poly.axes = for i in [0...len] by 2
    x1 = verts[i  ]
    y1 = verts[i+1]
    x2 = verts[(i+2)%len]
    y2 = verts[(i+3)%len]

    n = v.normalize v y1-y2, x2-x1
    d = v.dot2 n.x, n.y, x1, y1
    new Axis n, d

setupPoly = (poly) ->
  throw new Error 'points must be clockwise' unless polyValidate poly
  setAxes poly
  poly.tVerts = new Array poly.verts.length
  poly.tAxes = (new Axis v.zero, 0 for [0...poly.axes.length])

transformVerts = (poly, p, rot) ->
  src = poly.verts
  dst = poly.tVerts
  
  l = Infinity; r = -Infinity
  b = Infinity; t = -Infinity
  
  for i in [0...src.length] by 2
    x = src[i]
    y = src[i+1]

    if rot?
      vx = p.x + x*rot.x - y*rot.y
      vy = p.y + x*rot.y + y*rot.x
    else
      vx = p.x + x
      vy = p.y + y

    dst[i] = vx
    dst[i+1] = vy

    l = min l, vx
    r = max r, vx
    b = min b, vy
    t = max t, vy

  poly.bb_l = l
  poly.bb_b = b
  poly.bb_r = r
  poly.bb_t = t

transformAxes = (poly, p, rot) ->
  src = poly.axes
  dst = poly.tAxes
  
  for i in [0...src.length]
    n = if rot? then v.rotate src[i].n, rot else src[i].n
    dst[i].n = n
    dst[i].d = v.dot(p, n) + src[i].d

exports.poly = poly = (x, y, verts) ->
  p =
    verts: verts
    cachePos: (tpos, trot) ->
      if trot?
        trot = v.forangle trot if typeof trot is 'number'
        p = v.rotate v(x, y), trot
      else
        p = v(x, y)

      p = v(tpos.x + p.x, tpos.y + p.y) if tpos?

      transformVerts this, p, trot
      transformAxes this, p, trot
      this
    draw: ->
      #ctx.fillStyle = @owner.color or 'green'
      ctx.strokeStyle = 'black'
      ctx.lineWidth = 2

      ctx.beginPath()

      len = @verts.length

      ctx.moveTo @tVerts[len - 2], @tVerts[len - 1]
      for i in [0...len] by 2
        ctx.lineTo @tVerts[i], @tVerts[i+1]
      ctx.fill()
      ctx.stroke()
    type: 'poly'
    pointQuery: (p) ->
      return unless bbContainsVect2 @bb_l, @bb_b, @bb_r, @bb_t, p
      
      info = {shape:this}
      
      axes = @tAxes
      for i in [0...axes.length]
        n = axes[i].n
        dist = axes[i].d - v.dot(n, p)
        
        if dist < 0
          return
        else if dist < info.d
          info.d = dist
          info.n = n
      
      return info

    segmentQuery: (a, b) ->
      axes = @tAxes
      verts = @tVerts
      len = axes.length * 2
      
      for i in [0...axes.length]
        n = axes[i].n
        an = v.dot a, n
        continue if axes[i].d > an
        
        bn = v.dot b, n
        t = (axes[i].d - an)/(bn - an)
        continue if t < 0 or 1 < t
        
        point = v.lerp a, b, t
        dt = -v.cross n, point
        dtMin = -v.cross2 n.x, n.y, verts[i*2], verts[i*2+1]
        dtMax = -v.cross2 n.x, n.y, verts[(i*2+2)%len], verts[(i*2+3)%len]

        if dtMin <= dt && dt <= dtMax
          return {shape:this, t, n}

  setupPoly p

  p

exports.rect = (x, y, w, h) -> poly x, y, [0, 0,  0, h,  w, h,  w, 0]

swap = (collisions) ->
  for c in collisions
    c.n.x *= -1
    c.n.y *= -1
  collisions

exports.collide = (a, b) ->
  switch a.type
    when 'circle'
      switch b.type
        when 'circle'
          circle2circle a, b
        when 'poly'
          circle2poly a, b
        when 'segment'
          circle2segment a, b
    when 'segment'
      switch b.type
        when 'circle'
          swap circle2segment b, a
        when 'poly'
          segment2poly a, b
        when 'segment'
          []
    when 'poly'
      switch b.type
        when 'circle'
          swap circle2poly b, a
        when 'poly'
          poly2poly a, b
        when 'segment'
          swap segment2poly b, a


