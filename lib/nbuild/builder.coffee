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
CopyFiles     = require './copy-files'
RemoveFiles   = require './remove-files'

{normalize, basename, dirname, extname, join, existsSync, relative} = path

VARIABLE_REGEX_1 = /\$\(([\S]+?)\)/g
VARIABLE_REGEX_2 = /^\@\(([\S]+?)\)$/

###*
  * Batch command — execute multiple steps
  *
  * @private
  * @param {Object} builder
  * @param {String} name
  * @param {Object} options 
###

batch = (builder, name, options) ->
  for key, val of options when typeof val is 'object'
    builder.execConfig(key, val)
    
copy = (builder, name, options) ->
  builder.lock()
  cp = new CopyFiles options.source, options.destination, 
    replaceStrategy: CopyFiles.REPLACE_OLDER
    on_complete: (stat, cp) ->
      console.log "#{name}: #{stat.filesCopied} files copied".green
      rollback = cp.generateRollback()
      builder.setState(name, rollback: rollback)
      builder.unlock()
    on_progress: (ctx, cp) ->
      if builder.verbose and not ctx.skipped
        console.log "#{relative(process.cwd(), ctx.src)} -> #{relative(process.cwd(), ctx.dst)}".grey

remove = (builder, name, options) ->
  rm = new RemoveFiles options.items, on_remove: (item) ->
    console.log "remove #{relative(process.cwd(), item)}".grey if builder.verbose
  console.log "#{name}: #{rm.statistics.filesRemoved} files removed".green
  
rollback = (builder, name, options) ->
  rollback = builder.state[options['step-name']].rollback
  unless rollback?
    console.warn "Warning: rollback for `#{name}` didn't found.".yellow
    return
  for entry in rollback
    if entry.command is 'rm'
      fs.unlinkSync(entry.path) if existsSync(entry.path)
      console.log "rm #{entry.path}".grey if builder.verbose
    else if entry.command is 'rmdir'
      try
        fs.rmdirSync(entry.path) if existsSync(entry.path)
        console.log "rmdir #{entry.path}" if builder.verbose
      catch err
        console.warn "Warning: can't delete dir #{entry.path}".yellow
        
exec = (builder, name, options) ->
  builder.lock()
  oldDir = null
  if options["change-dir"]
    if existsSync(options["change-dir"])
      newDir = fs.realpathSync(options["change-dir"])
      oldDir = process.cwd()
      console.log "change dir to #{newDir}".cyan
      process.chdir(newDir)
    else
      builder.unlock()
      throw "Error: directory #{options["change-dir"]} not exists"
  n = 0
  console.log 'executing...'.cyan
  async.forEachSeries options.commands
  , (command, callback) -> 
    child_process.exec command, (err, stdout, stderr) ->
      if err is null
        console.log stdout if builder.verbose
        console.log "#{name}[#{n}]: `#{command}` successfully executed!".green
      else
        console.error stderr if builder.verbose
        console.error "Error: exec `#{command}` failed with error \"#{err}\"".red
      n++
      callback(0) 
  , (err) ->
    if oldDir
      process.chdir(oldDir)
    builder.unlock()
    
###* 
 * @class Builder сlass 
 * @public
 * @api
###
      
class Builder
  RESERVED_COMMANDS = ["@environment", "@type"]
  STATE_FILE = "_state.json"
  
  commands: {
    "batch": batch
    "copy": copy
    "remove": remove
    "rollback": rollback
    "exec": exec
  }
  
  ###*
  * @constructor
  * @public
  * @api
  * @param options.verbose     {Boolean}
  * @param options.environment {String}
  * @param options.configFiles {Array} array of path of config files
  * @param options.workDir     {String} path to work dir
  * @description
      1) initialize fields
      2) parse each config file
      3) set global defines
      4) set global defaults
      5) set environment
      6) set work directory to main config dir
      7) load state
  ###
  
  constructor: (options) ->
    throw 'Error! No config!' if options.configFiles.length is 0
    
    ###* 
    * @field verbose {Boolean}
    * @private 
    ###
    @verbose = options.verbose or no
    
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
    
    for name, node of @config when node['@type'] and node['@type'] is 'define'
      continue if node["@environment"] and node["@environment"] isnt @environment
      for key, val of node
        continue if key[0] is '@'
        @defines[key] = @_parseVars(val)
                        
    for key,val of @config when val['@type'] and val['@type'] is 'default'
      continue if node["@environment"] and node["@environment"] isnt @environment
      for key, val of node
        continue if key[0] is '@'
        @defaults[key] = @_parseVars(val)
        
    #   @_parseDefaults(val, @environment)
    # @_loadState()
    
    
    
  ###*
  * Parse variables
  * @private
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
  * @api
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
      
  _findCommandConfig: (cmdpath) ->
    current = @config
    for cmd in cmdpath
      throw "Error! Reserved command `#{cmd}`!" if _.indexOf(RESERVED_COMMANDS, cmd) isnt -1
      throw "Error! Unknown command `#{cmd}`!"  unless current[cmd]?
      current = current[cmd]
    return _.clone(current)
    
  ###*
  * Parse defines object
  * 
  * @private
  * @param defines {Object} object to parse
  * @param env {String} environment name
  * @return updated this.defines fiedld
  * @description
    
  ###
    
  _parseDefines: (define, env) ->
    
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