require "colors"
fs           = require 'fs'
util         = require 'util'
_            = require 'underscore'
path         = require 'path'
async        = require 'async'
{deepExtend} = require './helpers'

{basename, dirname, extname, join, existsSync} = path

_.templateSettings = interpolate : /\$\(([\S]+?)\)/g

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
      
bundle = (builder, name, options) ->
  console.log 'bundle', options
  for key, val of options when typeof val is 'object'
    builder.execConfig(key, val)
copy = (builder, name, options) ->
  console.log 'copy', options
remove = (builder, name, options) ->
  console.log 'remove', options
rollback = (builder, name, options) ->
  console.log 'rollback', options
exec = (builder, name, options) ->
  console.log 'exec', options
      
class Builder
  
  RESERVED_COMMANDS = ["_define", "_default", "_enveroument"]
  
  commands: {
    "bundle": bundle
    "copy": copy
    "remove": remove
    "rollback": rollback
    "exec": exec
  }
  constructor: (options) ->
    throw 'Error! No config!' if options.configFiles.length is 0
    @verbose = options.verbose or no

    @config = {}
    @defaults = {}
    hasLoad = no
    for configFile in options.configFiles
      continue unless configFile? and _.isString(configFile) and existsSync(configFile)
      json = fs.readFileSync(configFile, 'utf-8')
      parse = {}
      try
        parse = JSON.parse(json)
        hasLoad = yes
      catch err
        throw "JSON parse failed at #{configFile}"
      @config = deepExtend(@config, parse)
      unless @defines?
        @defines = 
          PROJECT_NAME: basename(options.configFiles[0], extname(options.configFiles[0]))
          PROJECT_DIR:  dirname(options.configFiles[0])
          CURRENT_DIR:  process.cwd()
      
    throw 'Error! No valid config!' unless hasLoad
    
    @enveroument = options.enveroument or @config._enveroument
    @_parseDefines(@config._define, @enveroument) if @config._define?
    @_parseDefaults(@config._default, @enveroument) if @config._default?
    
    # console.log 'defines', @defines
    console.log 'defaults', @defaults
    # console.log 'config', @config
    
  run: (cmdstr) ->
    cmdpath = cmdstr.split(':')
    @execConfig(cmdpath[cmdpath.length-1], @_findCommandConfig(cmdpath))

  execConfig: (name, options) ->
    type = options.type
    type = 'bundle' unless type?
    return unless @commands[type]?
    #throw "Error! Unknown type #{cmdcfg.type}!" unless @commands[type]?
    console.log "before".cyan, options
    options = @_expandConfig(options)
    console.log "after".cyan, options
    @commands[type](this, name, options)
  _expandString: (str) -> return _.template(str, @defines)
  _expandConfig: (cfg) ->
    result = {} 
    for key, val of cfg 
      if _.isString(val)
        result[key] = @_expandString(val)
      else if _.isArray(val)
        result[key] = _.map val, (s) => 
          return (if _.isString(s) then @_expandString(s) else s)
      else 
        result[key] = val
    return result
      
  _findCommandConfig: (cmdpath) ->
    current = @config
    throw "Error! Reserved command `#{cmdpath[0]}`!" if _.indexOf(RESERVED_COMMANDS, cmdpath[0]) isnt -1
    for cmd in cmdpath
      throw "Error! Unknown command `#{cmd}`!"  unless current[cmd]?
      current = current[cmd]
    return _.clone(current)
    
  _parseDefines: (defines, env) ->
    temp = {}
    temp[key] = val for key, val of defines when _.isString(val)
    for key, obj of defines when typeof obj is "object" and key is env
      temp[key] = val for key, val of obj when _.isString(val)
    for key, val of temp
      newKey = key.replace("-","_").toUpperCase()
      @defines[newKey] = _.template(val, @defines)
    return @defines
      
  _parseDefaults: (defaults, env) ->
    for key, val of defaults
      if _.isString(val)
        @defaults[key] = @_expandString(val)
      else if _.isArray(val)
        @defaults[key] = _.map val, (s) => 
          return (if _.isString(s) then @_expandString(s) else s)
      else if typeof val is "object" and key is env
        @_parseDefaults(val, null)
    return @defaults
        
  _loadPlugins: ->
    
module.exports = Builder