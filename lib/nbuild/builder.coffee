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

_.templateSettings = interpolate : /\$\(([\S]+?)\)/g
      
bundle = (builder, name, options) ->
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
    
    process.chdir(@defines.PROJECT_DIR)
    
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
    while not @_lock and @commandQue.length > 0
      @commandQue.shift()()
      
  setState: (name, value) ->
    if typeof @state[name] is 'object'
      @state[name] = _.extend @state[name], value
    else
      @state[name] = value
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
    options = @_expandConfig(options)
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
        data = fs.readFileSync(join(@defines.PROJECT_DIR, STATE_FILE), 'utf-8')
        @state = JSON.parse(data)
      catch err
        console.log "Warning: invalid state file #{STATE_FILE}!"
    else
      @state = {}

  _saveState: ->
    data = JSON.stringify(@state)
    fs.writeFileSync(join(@defines.PROJECT_DIR, STATE_FILE), data, 'utf-8')
      
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