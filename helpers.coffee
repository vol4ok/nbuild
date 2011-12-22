_ = require 'underscore'

deepExtend = ->
  args = []
  return false if arguments.length < 1 or typeof arguments[0] isnt "object"
  target = arguments[0]
  args.push arguments[i] for i in [1...arguments.length]
  return target unless args.length > 0
  for obj in args
    continue if typeof obj isnt "object"
    for key,val of obj when obj[key] isnt undefined
      src = target[key]
      continue if val is target
      if typeof val isnt "object"
        target[key] = val
        continue
      if typeof src isnt "object"
        clone = (if _.isArray(val) then [] else {})
        target[key] = deepExtend(clone, val)
        continue
      if _.isArray(val)
      then clone = (if (_.isArray(src)) then src else [])
      else clone = (unless _.isArray(src) then src else {})
      target[key] = deepExtend(clone, val)
  return target
  
exports.deepExtend = deepExtend