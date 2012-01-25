###!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###
 
 
###* Module dependencies ###

require "colors"
fs            = require 'fs'
util          = require 'util'
_             = require 'underscore'
path          = require 'path'
async         = require 'async'
{deepExtend}  = require './helpers'
child_process = require 'child_process'

{normalize, basename, dirname, extname, join, existsSync, relative} = path

VARIABLE_REGEX_1 = /\$\(([\S]+?)\)/g
VARIABLE_REGEX_2 = /^\@\(([\S]+?)\)$/
    
    
       
###* 
* @class Builder сlass 
* @public
* @api
###
      
class Builder
  RESERVED_COMMANDS = ["@environment", "@type"]
  STATE_FILE = "_state.json"
  
  ###*
  * @constructor
  * @public
  * @api
  * @param options.verbose     {Boolean}
  * @param options.environment {String}
  * @param options.configFiles {Array} array of path of config files
  * @param options.plugins     {Array} list of plugin or plugin's dirs
  * @description
      1) initialize fields
      2) parse each config file
      3) set global defines
      4) set global defaults
      5) set environment
      6) set work directory to main config dir
      7) oad plugins
      8) load statel
  ###
  
  constructor: (options) ->
    throw 'Error! No config!' if options.configFiles.length is 0
    
    ###* 
    * @field verbose {Boolean}
    * @public 
    ###
    @verbose = options.verbose or no
    
    ###* 
    * @field plugins {Boolean}
    * @private 
    ###
    @plugins = options.plugins or []
    
    ###* 
    * @field config {Object}
    * @private 
    ###
    @config = {}
    
    ###* 
    * @field defaults {Object}
    * @private 
    ###
    @commandQue = []
    
    ###* 
    * @field lock {Boolean}
    * @private 
    ###
    @lock = no
    
    ###* 
    * @field defaults {Object}
    * @public 
    ###
    @defaults = {}
    
    ###* 
    * @field defines {Object}
    * @public 
    ###
    @defines = null
        
    ###* 
    * @field environment {String}
    * @public 
    ###
    @environment = ""
    
    ###* 
    * @field types {Object}
    * @private 
    ###
    @types = 
      "batch":    _.bind(@_batch,    this)
      "rollback": _.bind(@_rollback, this)
      "define":   _.bind(@_define,   this)
      "default":  _.bind(@_default,  this)
    
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
      
    @environment = options.environment or @config["@environment"]
        
    for name, config of @config when config['@type'] and config['@type'] is 'define'
      @_define(name, config)
      
    for name, config of @config when config['@type'] and config['@type'] is 'default'
      @_default(name, config)
        
    @_scanPlugins()
    @_loadState()
      
      
    
  ###*
  * Locks class while async operation in process
  * @public
  ###
  
  lock: -> @lock = yes
  
  ###*
  * Unlock class, continue command execution
  * @public
  ###
  
  unlock: -> 
    @lock = no
    while not @lock and @commandQue.length > 0
      @commandQue.shift()()



  ###*
  * Set state
  * @public
  * @param name  {String}
  * @param value {Any}
  ###
  
  setState: (name, value) ->
    if typeof @state[name] is 'object'
      @state[name] = _.extend @state[name], value
    else
      @state[name] = value
      
  ###*
  * Load state from file
  * @private
  ###
  
  _loadState: ->
    if existsSync(STATE_FILE)
      try
        data = fs.readFileSync(join(@defines.PROJECT_DIR, STATE_FILE), 'utf-8')
        @state = JSON.parse(data)
      catch err
        console.log "Warning: invalid state file #{STATE_FILE}!"
    else
      @state = {}

  ###*
  * Save state to file
  * @private
  ###
  
  _saveState: ->
    data = JSON.stringify(@state)
    fs.writeFileSync(join(@defines.PROJECT_DIR, STATE_FILE), data, 'utf-8')



  ###*
  * Execute command string
  *
  * @public
  * @api
  * @param cmdstr {String}
  ###

  exec: (cmdstr) ->
    process.chdir(@defines.PROJECT_DIR)
    cmdpath = cmdstr.split(':')
    @execConfig(cmdpath[cmdpath.length-1], @_findCommandConfig(cmdpath))
    process.chdir(@defines.CURRENT_DIR)

  ###*
  * Execute config object
  *
  * @public
  * @param name    {String} config name
  * @param options {Object} config object
  ###
  
  execConfig: (name, options) ->
    if @_lock
      @commandQue.push(=> @execConfig(name, options))
      return
    type = options._type
    type = 'batch' unless type?
    return unless @commands[type]?
    options = @_expandConfig(options)
    @commands[type](this, name, options)
    @_saveState()
    
  ###*
  * Find command config
  *
  * @private
  * @param cmdpath {String}
  ###
      
  _findCommandConfig: (cmdpath) ->
    current = @config
    for cmd in cmdpath
      throw "Error! Reserved command `#{cmd}`!" if _.indexOf(RESERVED_COMMANDS, cmd) isnt -1
      throw "Error! Unknown command `#{cmd}`!"  unless current[cmd]?
      current = current[cmd]
    return _.clone(current)
    
    
    
  ###*
  * Scan and attach plugins
  *
  * @private
  * @description
    Plugin format:
      - plugin must export initialize(builder) function
      - plugin must have extension .plugin.coffee or .plugin.js
  ###
  
  _scanPlugins: ->
    for path in @plugins
      process.chdir(@defines.PROJECT_DIR)
      path = fs.realpathSync(path)
      process.chdir(@defines.CURRENT_DIR)
      if fs.lstatSync(path).isDirectory()
        for file in fs.readdirSync(path) 
          if /.*\.plugin\.(coffee|js)$/i.test(file)
            require(join(path,file)).initialize(this)
      else
        require(join(path)).initialize(this)
        
  ###*
  * Scan and attach plugins
  *
  * @public
  * @api
  * @param name {String}   type name
  * @param func {Function} handler function
  * @param obj  {Object}   this object for function, if function is class method
  ###
  
  registerType: (name, func, obj = null) ->
    if obj
      @types[name] = _.bind(func, obj)
    else
      @types[name] = func
      
      
      
  ###*
  * Batch command — execute multiple steps
  *
  * @private
  * @param name    {String} 
  * @param options {Object}  
  ###
    
  _batch: (name, options) ->
    for key, val of options when typeof val is 'object'
      @execConfig(key, val)

  ###*
  * Rollback step
  *
  * @private
  * @param name    {String} 
  * @param options {Object}  
  ###
  
  _rollback: (name, options) ->
    rollback = @state[options['step-name']].rollback
    unless rollback?
      console.warn "Warning: rollback for `#{name}` didn't found.".yellow
      return
    for entry in rollback
      if entry.command is 'rm'
        fs.unlinkSync(entry.path) if existsSync(entry.path)
        console.log "rm #{entry.path}".grey if @verbose
      else if entry.command is 'rmdir'
        try
          fs.rmdirSync(entry.path) if existsSync(entry.path)
          console.log "rmdir #{entry.path}" if builder.verbose
        catch err
          console.warn "Warning: can't delete dir #{entry.path}".yellow
      
  ###*
  * Parse define node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}  
  ###
  
  _define: (name, config) ->
    return if config["@environment"] and config["@environment"] isnt @environment
    for key, val of config
      continue if key[0] is '@'
      @defines[key] = @_parseVars(val)
      
  ###*
  * Parse default node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}  
  ###
  
  _default: (name, config) ->
    return if config["@environment"] and config["@environment"] isnt @environment
    for key, val of config
      continue if key[0] is '@'
      @defaults[key] = @_parseVars(val)



  _expandConfig: (config) ->
    result = {}
    for key, val of config
      continue if key[0] is '@'
      result[key] = @_parseVars(val)
    return result
    
  ###*
  * Parse variables
  * @private
  * @param val {Any} value for parse
  ###

  _parseVars: (val) ->
    replacer = (match, name, pos, str) => 
      i = 0
      while pos > 0 and str[pos-1] == '\\'
        pos--; i++
      if i % 2 is 1
        return match
      return if _.isString(@defines[name]) then @defines[name] else JSON.stringify(@defines[name])
    if _.isString(val)
      if VARIABLE_REGEX_2.test(val)
        return JSON.parse(val.replace(VARIABLE_REGEX_2, replacer))
      return val.replace(VARIABLE_REGEX_1, replacer)
    else
      return JSON.parse(JSON.stringify(val).replace(VARIABLE_REGEX_1, replacer))
      
module.exports = Builder