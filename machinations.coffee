Array::setRemove = (obj) ->
  i = @indexOf obj
  if i >= 0
    @[i] = @[@length-1]
    @length--
  i

class Diagram
  constructor: ->
    @stuff = []
  add: (thing) ->
    @stuff.push thing; thing
  remove: (thing) ->
    @stuff.setRemove thing
    thing.remove?()

  state: ->
    state = []
    for t in @stuff
      if (s = t.state?())?
        state.push [t, s]
    state
  restore: (state) ->
    t.reset?() for t in @stuff
    for [t,s] in state
      t.restore s
    return

class Pool
  constructor: (@tokens = 0) ->
    @out_arrows = []
    @in_arrows = []
    @mode = 'pull-all'

  take: (n) ->
    n = Math.min n, @tokens
    @tokens -= n
    @emit 'out', n
    n
  give: (n) ->
    @tokens += n
    @emit 'in', n if n > 0

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

  state: -> @tokens
  restore: (s) -> @tokens = s

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

  state: -> @label
  restore: (s) -> @label = s

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

class Gate
  constructor: ->
    @out_arrows = []
    @in_arrows = []
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

  reset: -> @count = 0

if typeof window is 'undefined'
  assert = require 'assert'
  tests = [
    ->
      p1 = new Pool 1
      p2 = new Pool
      g = new Gate
      a1 = new Arrow p1, g
      a2 = new Arrow g, p2
      assert.equal 1, p1.tokens
      assert.equal 0, p2.tokens
      p1.push()
      assert.equal 0, p1.tokens
      assert.equal 1, p2.tokens
    ->
      p1 = new Pool 2
      g = new Gate
      new Arrow p1, g
      p2 = new Pool
      p3 = new Pool
      new Arrow g, p2
      new Arrow g, p3
      p1.push()
      p1.push()
      assert.equal 0, p1.tokens
      assert.equal 2, p2.tokens + p3.tokens
    ->
      p1 = new Pool 2
      g = new Gate
      g.mode = 'deal'
      new Arrow p1, g
      p2 = new Pool
      p3 = new Pool
      new Arrow g, p2
      new Arrow g, p3
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
      a = new Arrow p1, p2
      new Arrow p2, p1
      m = new Modifier p2, a, 1
      p1.push()
      assert.equal a.label, 2
      p2.push()
      assert.equal a.label, 1
    ->
      d = new Diagram
      p1 = d.add new Pool 1
      p2 = d.add new Pool
      d.add new Arrow p1, p2
      s = d.state()
      p1.push()
      assert.equal 0, p1.tokens
      assert.equal 1, p2.tokens
      d.restore s
      assert.equal 1, p1.tokens
      assert.equal 0, p2.tokens
  ]
  t() for t in tests
