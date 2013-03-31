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
  div = document.createElement 'div'

  sweepIn = '50px'

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
    border:     '2px solid hsla(205,77%,76%,0.0)'
    webkitTransition: '150ms'
    pointerEvents: 'auto'

  sweep =
    webkitTransition: '150ms'
    position: 'relative'
    opacity: '0'
    left: sweepIn

  title = tag 'div', o.constructor.name
  style title, sweep

  makeRadio = (group, label) ->
    push = tag 'div'
    style push, sweep
    radio = push.appendChild tag 'input'
    radio.setAttribute 'type', 'radio'
    radio.setAttribute 'name', group
    push.appendChild tag 'label', label
    push
  action = tag 'div', 'action'
  style action, sweep
  push = makeRadio 'action', 'push'
  pull = makeRadio 'action', 'pull'
  if o.mode is 'pull-any'
    pull.firstChild.checked = true
  else
    push.firstChild.checked = true

  els = [title, action, push, pull]

  div.appendChild t for t in els

  t.style.webkitTransitionDelay = i*20+'ms' for t,i in els


  el: div
  animateIn: ->
    for t in els
      t.style.opacity = '1'
      t.style.left = '0'
    div.style.background = 'hsla(205,77%,76%,0.2)'
    div.style.border =     '2px solid hsla(205,77%,76%,0.3)'
  animateOut: ->
    for t in els
      t.style.opacity = '0'
      t.style.left = sweepIn
    div.style.background = 'hsla(205,77%,76%,0.0)'
    div.style.border =     '2px solid hsla(205,77%,76%,0.0)'
    els[0].addEventListener 'transitionend', ->
      div.remove()

