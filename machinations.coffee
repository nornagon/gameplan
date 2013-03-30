Array::setRemove = (obj) ->
  i = @indexOf obj
  if i >= 0
    @[i] = @[@length-1]
    @length--
  i

class Node
  constructor: ->
    @out_arrows = []
    @in_arrows = []

  arrow: (to) ->
    new Arrow @, to

class Pool extends Node
  constructor: (@tokens = 0)->
    super
    @mode = 'pull-all'

  take: (n) ->
    n = Math.min n, @tokens
    @tokens -= n
    @emit 'out', n
    n
  give: (n) ->
    @tokens += n
    @emit 'in', n

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

  activate: ->
    switch @mode
      when 'pull-all' then @pullAll()
      when 'push' then @push()


  on: (ev, listener) ->
    ((@listeners ?= {})[ev] ?= []).push listener
  removeListener: (ev, listener) ->
    ((@listeners ?= {})[ev] ?= []).setRemove listener
  emit: (ev, args...) ->
    l.apply undefined, args for l in ((@listeners ?= {})[ev] ?= [])

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

class Trigger
  constructor: (@src, @dst) ->
    @src.on 'in', @listener = =>
      @dst.activate()
  remove: ->
    @src.removeListener 'in', @listener

class Modifier
  constructor: (@src, @dst, @modifier) ->
    @src.on 'in', @in_listener = =>
      @dst.label += @modifier
    @src.on 'out', @out_listener = =>
      @dst.label -= @modifier
  remove: ->
    @src.removeListener 'in', @in_listener
    @src.removeListener 'out', @out_listener

class Gate extends Node
  constructor: ->
    super
    @mode = 'random'
    @count = 0

  give: (n) ->
    for [1..n]
      a = @pick()
      a.push 1
    return

  pick: ->
    total = 0
    for a in @out_arrows
      total += a.label
    if @mode is 'random'
      r = Math.random() * total
    else if @mode is 'deal'
      r = @count
      @count = (@count + 1) % total
    running_total = 0
    for a in @out_arrows
      running_total += a.label
      if r < running_total
        return a
    return

assert = require 'assert'
tests = [
  ->
    p1 = new Pool 1
    p2 = new Pool
    g = new Gate
    a1 = p1.arrow g
    a2 = g.arrow p2
    assert.equal 1, p1.tokens
    assert.equal 0, p2.tokens
    p1.push()
    assert.equal 0, p1.tokens
    assert.equal 1, p2.tokens
  ->
    p1 = new Pool 2
    g = new Gate
    p1.arrow g
    p2 = new Pool
    p3 = new Pool
    g.arrow p2
    g.arrow p3
    p1.push()
    p1.push()
    assert.equal 0, p1.tokens
    assert.equal 2, p2.tokens + p3.tokens
  ->
    p1 = new Pool 2
    g = new Gate
    g.mode = 'deal'
    p1.arrow g
    p2 = new Pool
    p3 = new Pool
    g.arrow p2
    g.arrow p3
    p1.push()
    p1.push()
    assert.equal 0, p1.tokens
    assert.equal 1, p2.tokens
    assert.equal 1, p3.tokens
  ->
    p = new Pool
    activated = 0
    t = new Trigger p, {activate:->activated++}
    p.give 1
    assert.equal activated, 1, 'activated'
  ->
    p1 = new Pool 1
    p2 = new Pool
    a = p1.arrow p2
    p2.arrow p1
    m = new Modifier p2, a, 1
    p1.push()
    assert.equal a.label, 2
    p2.push()
    assert.equal a.label, 1
]
t() for t in tests
