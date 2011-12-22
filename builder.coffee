fs = require 'fs'
util = require 'util'
_ = require 'underscore'
path = require 'path'
async = require 'async'
{deepExtend} = require './helpers'
{join, existsSync} = path

class FileCopier
  constructor: ->
    @numOfCopiedFiles = 0
    @maxNumOfCopiedFiles = 10
    @copyQueue = []
    
  copy: -> (src, dst, callback) ->
    return false unless existsSync(src)
    dstDir = dirname(dst)
    mkdir.sync(dstDir, "0755") unless existsSync(dstDir)
    if @numOfCopiedFiles >= @maxNumOfCopiedFiles
      @copyQueue.push(=> @_copy(src, dst, callback))
    else
      @_copy(src, dst, callback)
      
  _copy: (src, dst, callback) ->
    @numOfCopiedFiles++
    util.pump fs.createReadStream(src), fs.createWriteStream(dst), (err) ->
      @numOfCopiedFiles--;
      @copyQueue.shift()() while @numOfCopiedFiles < @maxNumOfCopiedFiles
      callback(err) if _.isFunction(callback)
      
class Builder
  constructor: (options) ->
    @verbose = options.verbose or no
    @defines = PROJECT_DIR: __dirname
    @commands = {}
    @config = {}
    
    console.log options
    
    load = no
    for configFile in options.configs
      continue unless configFile? and _.isString(configFile) and existsSync(configFile)
      json = fs.readFileSync(configFile, 'utf-8')
      parse = {}
      try
        parse = JSON.parse(json)
        load = yes
      catch err
        console.log "JSON parse failed at #{configFile}".red
        return
    @config = deepExtend(@config, parse)
    return unless load
    
    console.log @config
    
    @enveroument = options.enveroument or @config.enveroument
    
    for key, val  of @config
      continue unless typeof val is "object"
      switch key
        when 'define' then @_parseDefines(val)
        else @_parseCommand(key, val) 
    console.log @commands
    
  run: (command) ->
    
  _parseDefines: (defines) ->
    temp = {}
    temp[key] = val for key, val of defines when _.isString(val)
    for key, obj of defines when typeof obj is "object" and key is @enveroument
      temp[key] = val for key, val of obj when _.isString(val)
    
    oldTemplateSettings = _.templateSettings
    _.templateSettings = interpolate : /\$\(([\S]+?)\)/g
    for key, val of temp
      newKey = key.replace("-","_").toUpperCase()
      @defines[newKey] = _.template(val, @defines)
    _.templateSettings = oldTemplateSettings
    
    console.log @defines
  
  _parseCommand: (cmd, steps) ->
    @commands[cmd] = steps
    
  _loadPlugins: ->
    
module.exports = Builder