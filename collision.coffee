# Stolen from Chipmunk

min = Math.min
max = Math.max

#v = require './vect'
Vect = v.Vect
exports = window

Contact = (@p, @n, @dist) ->
  this.r1 = this.r2 = v.zero
  this.nMass = this.tMass = this.bounce = this.bias = 0

  this.jnAcc = this.jtAcc = this.jBias = 0

NONE = []


# Add contact points for circle to circle collisions.
# Used by several collision tests.
circle2circleQuery = (p1, p2, r1, r2) ->
  mindist = r1 + r2
  delta = v.sub(p2, p1)
  distsq = v.lensq(delta)
  return if distsq >= mindist*mindist
  
  dist = Math.sqrt distsq

  # Allocate and initialize the contact.
  new Contact(
    v.add(p1, v.mult(delta, 0.5 + (r1 - 0.5*mindist)/(dist ? dist : Infinity))),
    (if dist then v.mult(delta, 1/dist) else new Vect 1, 0),
    dist - mindist
  )

# Collide circle shapes.
exports.circle2circle = (circ1, circ2) ->
  contact = circle2circleQuery circ1.tc, circ2.tc, circ1.r, circ2.r
  if contact then [contact] else NONE

exports.circle2segment = (circleShape, segmentShape) ->
  seg_a = segmentShape.ta
  seg_b = segmentShape.tb
  center = circleShape.tc
  
  seg_delta = v.sub(seg_b, seg_a)
  closest_t = v.clamp01(v.dot(seg_delta, v.sub(center, seg_a))/v.lensq(seg_delta))
  closest = v.add(seg_a, v.mult(seg_delta, closest_t))
  
  contact = circle2circleQuery(center, closest, circleShape.r, segmentShape.r)

  if contact then [contact] else NONE

valueOnAxis = (poly, n, d) ->
  tVerts = poly.tVerts
  m = v.dot2 n.x, n.y, tVerts[0], tVerts[1]
  
  for i in [2...tVerts.length] by 2
    m = min m, v.dot2(n.x, n.y, tVerts[i], tVerts[i+1])
  
  m - d

containsVert = (poly, vx, vy) ->
  tAxes = poly.tAxes
  for i in [0...tAxes.length]
    n = tAxes[i].n
    dist = v.dot2(n.x, n.y, vx, vy) - tAxes[i].d
    return false if dist > 0
  
  true

containsVertPartial = (poly, vx, vy, n) ->
  tAxes = poly.tAxes
  for i in [0...tAxes.length]
    n2 = tAxes[i].n
    continue if(v.dot(n2, n) < 0)
    dist = v.dot2(n2.x, n2.y, vx, vy) - tAxes[i].d
    return false if dist > 0
  
  true

# Find the minimum separating axis for the given poly and axis list.
#
# This function needs to return two values - the index of the min. separating axis and
# the value itself. Short of inlining MSA, returning values through a global like this
# is the fastest implementation.
#
# See: http://jsperf.com/return-two-values-from-function/2
last_MSA_min = 0
findMSA = (poly, axes) ->
  min_index = 0
  msa_min = valueOnAxis poly, axes[0].n, axes[0].d
  return -1 if msa_min > 0
  
  for i in [1...axes.length]
    dist = valueOnAxis poly, axes[i].n, axes[i].d
    return -1 if dist > 0

    if dist > msa_min
      msa_min = dist
      min_index = i
  
  last_MSA_min = msa_min
  return min_index

# Add contacts for probably penetrating vertexes.
# This handles the degenerate case where an overlap was detected, but no vertexes fall inside
# the opposing polygon. (like a star of david)
findVertsFallback = (poly1, poly2, n, dist) ->
  arr = []

  verts1 = poly1.tVerts
  for i in [0...verts1.length] by 2
    vx = verts1[i]
    vy = verts1[i+1]
    if containsVertPartial poly2, vx, vy, v.neg(n)
      arr.push new Contact new Vect(vx, vy), n, dist
  
  verts2 = poly2.tVerts
  for i in [0...verts2.length] by 2
    vx = verts2[i]
    vy = verts2[i+1]
    if containsVertPartial poly1, vx, vy, n
      arr.push new Contact new Vect(vx, vy), n, dist
  
  arr

# Add contacts for penetrating vertexes.
findVerts = (poly1, poly2, n, dist) ->
  arr = []

  verts1 = poly1.tVerts
  for i in [0...verts1.length] by 2
    vx = verts1[i]
    vy = verts1[i+1]
    if containsVert poly2, vx, vy
      arr.push new Contact new Vect(vx, vy), n, dist
    
  verts2 = poly2.tVerts
  for i in [0...verts2.length] by 2
    vx = verts2[i]
    vy = verts2[i+1]
    if containsVert poly1, vx, vy
      arr.push new Contact new Vect(vx, vy), n, dist
  
  if arr.length then arr else findVertsFallback poly1, poly2, n, dist

# Collide poly shapes together.
exports.poly2poly = (poly1, poly2) ->
  mini1 = findMSA poly2, poly1.tAxes
  return NONE if mini1 is -1
  min1 = last_MSA_min
  
  mini2 = findMSA poly1, poly2.tAxes
  return NONE if mini2 is -1
  min2 = last_MSA_min

  # There is overlap, find the penetrating verts
  if min1 > min2
    findVerts poly1, poly2, poly1.tAxes[mini1].n, min1
  else
    findVerts poly1, poly2, v.neg(poly2.tAxes[mini2].n), min2

# Like cpPolyValueOnAxis(), but for segments.
segValueOnAxis = (seg, n, d) ->
  a = v.dot(n, seg.ta) - seg.r
  b = v.dot(n, seg.tb) - seg.r
  min(a, b) - d

# Identify vertexes that have penetrated the segment.
findPointsBehindSeg = (arr, seg, poly, pDist, coef) ->
  dta = v.cross(seg.tn, seg.ta)
  dtb = v.cross(seg.tn, seg.tb)
  n = v.mult(seg.tn, coef)
  
  verts = poly.tVerts
  for i in [0...verts.length] by 2
    vx = verts[i]
    vy = verts[i+1]
    if v.dot2(vx, vy, n.x, n.y) < v.dot(seg.tn, seg.ta)*coef + seg.r
      dt = v.cross2 seg.tn.x, seg.tn.y, vx, vy
      if dta >= dt && dt >= dtb
        arr.push new Contact new Vect(vx, vy), n, pDist
  return

exports.segment2poly = (seg, poly) ->
  arr = []

  axes = poly.tAxes
  numVerts = axes.length
  
  segD = v.dot(seg.tn, seg.ta)
  minNorm = valueOnAxis(poly, seg.tn, segD) - seg.r
  minNeg = valueOnAxis(poly, v.neg(seg.tn), -segD) - seg.r
  return NONE if minNeg > 0 or minNorm > 0
  
  mini = 0
  poly_min = segValueOnAxis seg, axes[0].n, axes[0].d
  return NONE if poly_min > 0
  for i in [0...numVerts]
    dist = segValueOnAxis seg, axes[i].n, axes[i].d
    if dist > 0
      return NONE
    else if dist > poly_min
      poly_min = dist
      mini = i
  
  poly_n = v.neg axes[mini].n
  
  va = v.add seg.ta, v.mult poly_n, seg.r
  vb = v.add seg.tb, v.mult poly_n, seg.r
  if containsVert poly, va.x, va.y
    arr.push new Contact va, poly_n, poly_min
  if containsVert poly, vb.x, vb.y
    arr.push new Contact vb, poly_n, poly_min
  
  if minNorm >= poly_min or minNeg >= poly_min
    if minNorm > minNeg
      findPointsBehindSeg arr, seg, poly, minNorm, 1
    else
      findPointsBehindSeg arr, seg, poly, minNeg, -1
  
  # If no other collision points are found, try colliding endpoints.
  if arr.length is 0
    mini2 = mini * 2
    verts = poly.tVerts

    poly_a = new Vect verts[mini2], verts[mini2+1]
    
    if (con = circle2circleQuery seg.ta, poly_a, seg.r, 0, arr) then return [con]
    if (con = circle2circleQuery seg.tb, poly_a, seg.r, 0, arr) then return [con]

    len = numVerts * 2
    poly_b = new Vect verts[(mini2+2)%len], verts[(mini2+3)%len]
    if (con = circle2circleQuery(seg.ta, poly_b, seg.r, 0, arr)) then return [con]
    if (con = circle2circleQuery(seg.tb, poly_b, seg.r, 0, arr)) then return [con]

  arr

exports.circle2poly = (circ, poly) ->
  axes = poly.tAxes
  
  mini = 0
  least = v.dot(axes[0].n, circ.tc) - axes[0].d - circ.r
  for i in [0...axes.length]
    dist = v.dot(axes[i].n, circ.tc) - axes[i].d - circ.r
    if dist > 0
      return NONE
    else if dist > least
      least = dist
      mini = i
  
  n = axes[mini].n

  verts = poly.tVerts
  len = verts.length
  mini2 = mini<<1

  #var a = poly.tVerts[mini]
  #var b = poly.tVerts[(mini + 1)%poly.tVerts.length]
  x1 = verts[mini2]
  y1 = verts[mini2+1]
  x2 = verts[(mini2+2)%len]
  y2 = verts[(mini2+3)%len]

  dta = v.cross2 n.x, n.y, x1, y1
  dtb = v.cross2 n.x, n.y, x2, y2
  dt = v.cross n, circ.tc
    
  if dt < dtb
    con = circle2circleQuery(circ.tc, new Vect(x2, y2), circ.r, 0, con)
    if con then [con] else NONE
  else if dt < dta
    [new Contact(
      v.sub(circ.tc, v.mult(n, circ.r + least/2)),
      v.neg(n),
      least
    )]
  else
    con = circle2circleQuery(circ.tc, new Vect(x1, y1), circ.r, 0, con)
    if con then [con] else NONE
