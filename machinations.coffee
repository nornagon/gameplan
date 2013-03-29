Array::setRemove = (obj) ->
  i = @indexOf obj
  if i >= 0
    @[i] = @[@length-1]
    @length--
  i

class Machine
  constructor: ->
  tick: ->

class Node
  constructor: ->
    @out_arrows = []
    @in_arrows = []

  arrow: (to) ->
    new Arrow @, to

class Pool extends Node
  constructor: ->
    super
    @mode = 'pull-all'
    @tokens = 0

  take: (n) -> @tokens -= n; n
  give: (n) -> @tokens += n

  pullAll: ->
    for a in @in_arrows
      return unless a.canPull()
    num = 0
    for a in @in_arrows
      num += a.pull()
    @give num

  push: ->
    for a in @out_arrows
      a.push @take a.label
    return

class Arrow
  constructor: (@src, @dst) ->
    @src.out_arrows.push @
    @dst.in_arrows.push @
    @label = 1
  remove: ->
    @src.out_arrows.setRemove @
    @dst.in_arrows.setRemove @
  canPull: -> @src.tokens >= @label
  pull: ->
    if @src.tokens >= @label
      return @src.take @label
    return 0
  push: (n) ->
    @dst.give n

class Gate extends Node
  constructor: ->
    super

  give: (n) ->
    for [1..n]
      a = @pick()
      a.push 1
    return

  pick: ->
    total = 0
    for a in @out_arrows
      total += a.label
    r = Math.random() * total
    running_total = 0
    for a in @out_arrows
      running_total += a.label
      if r < running_total
        return a
    return

assert = require 'assert'
test = ->
  p1 = new Pool
  p1.tokens = 1
  p2 = new Pool
  g = new Gate
  a1 = p1.arrow g
  a2 = g.arrow p2
  assert.equal 1, p1.tokens
  assert.equal 0, p2.tokens
  p1.push()
  assert.equal 0, p1.tokens
  assert.equal 1, p2.tokens
test()
