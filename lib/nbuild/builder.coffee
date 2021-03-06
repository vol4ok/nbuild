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
CSON          = require 'CSON'
YAML          = require 'js-yaml'
{deepExtend}  = require './helpers'

{normalize, basename, dirname, extname, join, existsSync, relative} = path

YAML_REGEX        = /^\s*#YAML/i
CSON_REGEX        = /^\s*#CSON/i
VARIABLE_REGEX    = /\$\(([\S]+?)\)/g
JSON_CMD_REGEX    = /^\$json\(([\S]+?)\)$/i
# JS_CMD_REGEX      = /^\$js\(([\S]+?)\)$/i
# PLUGIN_CMD_REGEX  = /^\$plugin\(([\S]+?)\)$/i
# INCLUDE_CMD_REGEX = /^\$include\(([\S]+?)\)$/i
    
###
TODO
  rename some variables
  
  поддержка внутренних переменных внутри скоупа и апи для них
  базовый при для работы с файловой системой
  @json() команда на парсинга json
  @js() команда на выполнения js скрипта
  @plugin(path) команда подключания кастом плагина
  поддержка зависимостей (ключ @depend)
  @include() подгрузка сторонних конфигов
  
  парсинг cson
###
       
###* 
* @class Builder сlass 
* @public
* @api
###
      
class Builder
  RESERVED_COMMANDS = ["$environment", "$type"]
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
    @plugins = []
    
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
    @_lock = no
    
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
    * @field defaultsStack {Array}
    * @private 
    ###
    @defaultsStack = []
    
    ###* 
    * @field definesStack {Array}
    * @private 
    ###
    @definesStack = []
        
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
      "define":   _.bind(@_define,   this)
      "default":  _.bind(@_default,  this)
      "rollback": _.bind(@_rollback, this)
      "call":     _.bind(@_call,     this)
      "plugin":   _.bind(@_plugin,   this)
      
    hasLoad = no
    for configFile in options.configFiles
      continue unless configFile? and _.isString(configFile) and existsSync(configFile)
      data  = fs.readFileSync(configFile, 'utf-8')
      parse = {}
      try
        if YAML_REGEX.test(data)
          parse = YAML.load(data)
        else if CSON_REGEX.test(data)
          parse = CSON.parse(data)
        else
          parse = JSON.parse(data)
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
    
    debugger
      
    @environment = options.environment or @config["$environment"]
        
    for name, config of @config when config['$type'] and config['$type'] is 'define'
      @_define(name, config)
      
    for name, config of @config when config['$type'] and config['$type'] is 'default'
      @_default(name, config)
      
    for name, config of @config when config['$type'] and config['$type'] is 'plugin'
      @_plugin(name, config)
        
    @_scanPlugins(options.plugins)
    
    @_loadState()
      
      
    
  ###*
  * Locks class while async operation in process
  * @public
  ###
  
  lock: -> @_lock = yes
  
  ###*
  * Unlock class, continue command execution
  * @public
  ###
  
  unlock: -> 
    @_lock = no
    while not @_lock and @commandQue.length > 0
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
    @_saveState()
      
  ###*
  * Load state from file
  * @private
  ###
  
  _loadState: ->
    path = join(@defines.PROJECT_DIR, STATE_FILE)
    if existsSync(path)
      try
        data = fs.readFileSync(path, 'utf-8')
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
  * Execute command string; For externals calls
  *
  * @public
  * @api
  * @param cmdstr {String}
  ###

  exec: (cmdstr) ->
    process.chdir(@defines.PROJECT_DIR)
    @_exec(cmdstr)
    process.chdir(@defines.CURRENT_DIR)

  ###*
  * Execute command string; For internals calls
  *
  * @private
  * @param cmdstr {String}
  ###
  
  _exec: (cmdstr) ->
    cmdpath = cmdstr.split(':')
    @execConfig(cmdpath[cmdpath.length-1], @_findCommandConfig(cmdpath))
  
  ###*
  * Execute config object
  *
  * @public
  * @param name    {String} config name
  * @param options {Object} config object
  ###
  
  execConfig: (name, config) ->
    if @_lock
      @commandQue.push(=> @execConfig(name, config))
      return
    type = config['$type']
    type = 'batch' unless type?
    return unless @types[type]?
    if type isnt 'batch' and 
       type isnt 'default' and 
       type isnt 'define'
      config = @_expandConfig(config) 
    @types[type](name, config)
    
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
  
  _scanPlugins: (plugins) ->
    return unless _.isArray(plugins)
    for path in plugins
      process.chdir(@defines.PROJECT_DIR)
      path = fs.realpathSync(path)
      process.chdir(@defines.CURRENT_DIR)
      if fs.lstatSync(path).isDirectory()
        for file in fs.readdirSync(path) 
          if /.*\.plugin\.(coffee|js)$/i.test(file)
            fullpath = join(path,file)
            try
              require(fullpath).initialize(this)
              @plugins.push(fullpath)
            catch err
              console.warn "Warning: load plugin `#{fullpath}` failed!".yellow
      else
        try
          require(path).initialize(this)
          @plugins.push(path)
        catch err
          console.warn "Warning: load plugin `#{path}` failed!".yellow
        
        
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
    if obj?
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
    @definesStack.push(_.clone(@defines))
    @defaultsStack.push(_.clone(@defaults))
    for key, val of options when typeof val is 'object'
      @execConfig(key, val)      
    delete @defines
    @defines = @definesStack.pop()
    delete @defaults
    @defaults = @defaultsStack.pop()
      
  ###*
  * Parse define node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}  
  ###
  
  _define: (name, config) ->
    return if config["$environment"] and config["$environment"] isnt @environment
    for key, val of config
      continue if key[0] is '$'
      @defines[key] = @_parseVars(val)
            
  ###*
  * Parse default node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}  
  ###
  
  _default: (name, config) ->
    return if config["$environment"] and config["$environment"] isnt @environment
    for key, val of config
      continue if key[0] is '$'
      @defaults[key] = @_parseVars(val)
      
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
          console.log "rmdir #{entry.path}" if @verbose
        catch err
          console.warn "Warning: can't delete dir #{entry.path}".yellow
    delete @state[options['step-name']]
    @_saveState()

  ###*
  * call node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}  
  ###
  
  _call: (name, config) ->
    if _.isArray(config.command)
      for cmd in config.command
        @_exec(cmd)
    else
      @_exec(config.command)
      
  ###*
  * load plugin node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}  
  ###
  _plugin: (name, config) ->
    if config.plugin?
      @_scanPlugins([config.plugin])
    if config.plugins?
      @_scanPlugins(config.plugins)
    

  ###*
  * Parse vars of each config entry
  *
  * @private
  * @param config  {Object} 
  ###
  
  _expandConfig: (config) ->
    result = _.clone(@defaults)
    for key, val of config
      continue if key[0] is '$'
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
      if JSON_CMD_REGEX.test(val)
        return JSON.parse(val.replace(JSON_CMD_REGEX, replacer))
      return val.replace(VARIABLE_REGEX, replacer)
    else
      return JSON.parse(JSON.stringify(val).replace(VARIABLE_REGEX, replacer))
      
module.exports = Builder