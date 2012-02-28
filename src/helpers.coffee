###!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###

###* Module dependencies ###

fs   = require 'fs'
path = require 'path'
_    = require 'underscore'

{normalize, basename, dirname, extname, join, existsSync, relative} = path

rand = (n) -> Math.floor(Math.random()*n)

generateName = (alphabet, length) ->
  name = ""
  for i in [0...length]
    name += alphabet[rand(alphabet.length)]
  return name
  
mkdirp = (path, mode = 0755, createdDirs = null) -> 
  parent = dirname(path)
  mkdirp(parent, mode) unless existsSync(parent)
  unless existsSync(path)
    fs.mkdirSync(path, mode) 
    createdDirs.push(path) if _.isArray(createdDirs)

cleanDir = (path) ->
  for f in fs.readdirSync(path)
    fs.unlinkSync(join(path,f))
  
generateFiles = (dir, count, maxSize, callback) ->
  files = []
  for i in [0...count]
    files.push join(dir, generateName(ALPHABET, 10))
  async.forEach files, (file, cb) -> 
    exec "dd if=/dev/urandom of=#{file} bs=1 count=#{rand(maxSize)}", cb
  , callback
  return files

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
  
exports extends {rand, generateName, mkdirp, cleanDir, generateFiles, deepExtend}