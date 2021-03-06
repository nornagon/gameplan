tag = (name, text) ->
  parts = name.split /(?=[.#])/
  tagName = "div"
  classes = []
  for p in parts
    if p[0] is '#'
      id = p.substr 1
    else if p[0] is '.'
      classes.push p.substr 1
    else
      tagName = p
  element = document.createElement tagName
  if typeof id isnt 'undefined'
    element.id = id
  element.classList.add c for c in classes
  if text
    element.textContent = text
  return element

style = (el, styles) ->
  for prop, val of styles
    el.style[prop] = val
  return el

makeOptionsUIFor = (o) ->
  div = tag 'div.options'

  sweepIn = 'translateX(50px)'

  style div,
    position: 'absolute'
    top: '0'
    right: '0'
    margin: '5px'
    padding: '5px'
    fontSize: '18px'
    width: '150px'
    borderRadius: '4px'
    background: 'hsla(205,77%,76%,0.0)'
    border: '2px solid hsla(205,77%,76%,0.0)'
    webkitTransition: '150ms'
    pointerEvents: 'auto'
    lineHeight: '0.8'

  sweep =
    webkitTransition: '150ms'
    opacity: '0'
    webkitTransform: sweepIn

  title = tag 'div', o.constructor.name
  style title, sweep
  style title, textDecoration: 'underline', marginBottom: '5px'

  makeRadio = (group, label) ->
    t = tag 'div'
    radio = t.appendChild tag 'input'
    radio.setAttribute 'type', 'radio'
    radio.setAttribute 'name', group
    t.appendChild tag 'label', label
    t

  if o instanceof Pool
    action = tag 'div', 'Action:'
    style action, sweep
    push = makeRadio 'action', 'push'
    style push, sweep
    pull = makeRadio 'action', 'pull'
    style pull, sweep
    if o.mode is 'pull-any'
      pull.firstChild.checked = true
    else
      push.firstChild.checked = true

    push.onclick = pull.onclick = ->
      o.mode = if push.firstChild.checked
        'push'
      else if pull.firstChild.checked
        'pull-any'

    resources = tag 'div', 'Tokens: '
    style resources, sweep
    inp = resources.appendChild tag 'input'
    inp.setAttribute 'type', 'number'
    inp.value = o.tokens
    inp.setAttribute 'min', '0'
    style inp,
      width: '40px'
      background: 'transparent'
      border: '1px solid black'
      font: 'inherit'
    inp.oninput = (e) ->
      n = inp.valueAsNumber
      n = 0 if isNaN n
      o.tokens = n
      draw()

    els = [title, action, push, pull, resources]
  else
    els = [title]

  div.appendChild t for t in els

  t.style.webkitTransitionDelay = i*20+'ms' for t,i in els


  el: div
  animateIn: ->
    for t in els
      t.style.opacity = '1'
      t.style.webkitTransform = 'translateX(0)'
    div.style.background = 'hsla(205,77%,76%,0.2)'
    div.style.border = '2px solid hsla(205,77%,76%,0.3)'
  animateOut: ->
    for t in els
      t.style.opacity = '0'
      t.style.webkitTransform = sweepIn
    div.style.background = 'hsla(205,77%,76%,0.0)'
    div.style.border = '2px solid hsla(205,77%,76%,0.0)'
    els[0].addEventListener 'transitionend', ->
      div.remove()


makeToolbar = ->
  tb = tag 'div'
  style tb,
    width: '-webkit-calc(100% - 14px)'
    position: 'absolute'
    bottom: '0'
    left: '5px'
    background: 'hsla(205,77%,76%,0.4)'
    padding: '2px'
    borderTopLeftRadius: '5px'
    borderTopRightRadius: '5px'
    pointerEvents: 'auto'
  tb

makePlaceButton = (name) ->
  b = tag 'button', name
  style b,
    font: 'inherit'
    border: '1px solid black'
    background: 'white'
    borderRadius: '3px'
  b
