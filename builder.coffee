require "colors"
fs           = require 'fs'
util         = require 'util'
_            = require 'underscore'
path         = require 'path'
async        = require 'async'
{deepExtend} = require './helpers'

{normalize, basename, dirname, extname, join, existsSync} = path

_.templateSettings = interpolate : /\$\(([\S]+?)\)/g
      
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
  RESERVED_COMMANDS = ["_define", "_default", "_enveroument", "_type"]
  STATE_FILE = "_state.json"
  
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
    @commandQue = []
    @_lock = no
    
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
    
    @_loadState()
    
    # console.log 'defines', @defines
    console.log 'defaults', @defaults
    # console.log 'config', @config
    
  lock: -> @_lock = yes
  unlock: -> 
    @_lock = no
    while @commandQue.length > 0
      @commandQue.shift()()
  
  run: (cmdstr) ->
    cmdpath = cmdstr.split(':')
    @execConfig(cmdpath[cmdpath.length-1], @_findCommandConfig(cmdpath))

  execConfig: (name, options) ->
    if @_lock
      @commandQue.push(=> @execConfig(name, options))
      return
    type = options._type
    type = 'bundle' unless type?
    return unless @commands[type]?
    #throw "Error! Unknown type #{cmdcfg.type}!" unless @commands[type]?
    #console.log "before".cyan, options
    options = @_expandConfig(options)
    #console.log "after".cyan, options
    @commands[type](this, name, options)
    @_saveState()
    
  _expandString: (str) -> return _.template(str, @defines)
  _expandConfig: (cfg) ->
    result = {} 
    for key, val of cfg 
      if _.isString(val)
        result[key] = @_expandString(val)
      else if _.isArray(val)
        result[key] = _.map val, (s) => if _.isString(s) then @_expandString(s) else s
      else 
        result[key] = val
    return result
      
  _findCommandConfig: (cmdpath) ->
    current = @config
    for cmd in cmdpath
      throw "Error! Reserved command `#{cmd}`!" if _.indexOf(RESERVED_COMMANDS, cmd) isnt -1
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
    
  _loadState: ->
    if existsSync(STATE_FILE)
      try
        data = fs.readFileSync(join(__dirname, STATE_FILE), 'utf-8')
        @state = JSON.parse(data)
      catch err
        console.log "Warning: invalid state file #{STATE_FILE}!"
    else
      @state = {}

  _saveState: ->
    data = JSON.stringify(@state)
    fs.writeFileSync(join(__dirname, STATE_FILE), data, 'utf-8')
      
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