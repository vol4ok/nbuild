###!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###


###* Module dependencies ###

require "colors"
fs     = require 'fs'
util   = require 'util'
_      = require 'underscore'
path   = require 'path'
coffee = require 'coffee-script'

{join, dirname, basename, extname, normalize, relative, existsSync} = path


exports.initialize = (builder) -> new RequirePlugin(builder)

class RequirePlugin
  
  constructor: (@builder) ->
    @targets = null
    @includeDirs = null
    @outputDir = null
    @fileExts = null
    @requireRegexp = /.*#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*).*\r?\n?/g
    @enumerate = "NONE"
    @removeLines = no
    @outputVar = null
    @builder.registerType('require', @require, this)
  
  ###* 
  * Handle require steps
  * 
  * @param {String} name — node name
  * @param {Array}  options.targets
  * @param {Array}  options["include-dirs"]
  * @param {String} options["output-dir"]
  * @param {Array}  [ options["file-exts"]      = null ]   
  * @param {RegExp} [ options["require-regexp"] = /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g ] 
  * @param {String} [ options.enumerate         = "PLAIN" ] "PLAIN"|"TREE"|"NONE"
  * @param {String} [ options.remove-lines      = "no" ] ???
  * @param {String} [ options.output-var        = null ] ???
  ###
  
  require: (name, options) ->
    throw "Error: `targets` is required attribute" unless options.targets?
    throw "Error: `include-dirs` is required attribute" unless options['include-dirs']?
    throw "Error: `output-dir` is required attribute" unless options['output-dir']?
    @targets = options.targets
    @includeDirs = options['include-dirs']
    @outputDir = options['output-dir']
    @fileExts = options['file-exts'] if options['file-exts']?
    @requireRegexp = options['require-regexp'] if options['require-regexp']?
    @enumerate = options['enumerate'].toUpperCase()
    @removeLines = if /^(yes|true|on)$/i.test(options['remove-lines']) then yes
    console.log @removeLines
    
    @index = @_indexIncludeDirs(@includeDirs)
    for target in @targets
      deps = @_findDependencies(target)
      console.log util.inspect(deps, no, null, yes)
      @_saveFiles(deps)
    
    
    
  _indexIncludeDirs: (includeDirs, prefix = '') ->
    index = {}
    includeDirs = [includeDirs] unless _.isArray(includeDirs)
    for dir in includeDirs
      for file in fs.readdirSync(dir)
        fullPath = join(dir,file)
        rx = new RegExp("^(.+)\\.(#{@fileExts.join('|')})$",'i')
        if rx.test(file)
          t = rx.exec(file)
          name = join(prefix,t[1])
          index[name] = 
            name: name
            type: t[2]
            path: fullPath
        else if fs.statSync(fullPath).isDirectory()
          name = join(prefix,file)
          index[name] = 
            name: name
            type: 'dir'
            path: fullPath
          index extends @_indexIncludeDirs(fullPath, name)
    return index
    
  _parseRequireDirective: (content) ->
    result = []
    content = '\n' + content
    result.push(match[1]) while (match = @requireRegexp.exec(content)) isnt null
    return result

  _findDependencies: (targets) ->
    result = []
    targets = [targets] unless _.isArray(targets)
    for target in targets
      if @index[target]?
        d = _.clone(@index[target])
        d.data = fs.readFileSync(d.path, 'utf8')
        r = @_parseRequireDirective(d.data)
        d.deps = @_findDependencies(r)
        result.push(d)
      else 
        console.log "Error: #{target} not found".red
    return result
    
  _mkdirp: (path, mode = 0755) -> 
    parent = dirname(path)
    @_mkdirp(parent, mode) unless existsSync(parent)
    fs.mkdirSync(path, mode) unless existsSync(path)
    
  _saveFiles: (tree) ->
    context = {}
    result = []
    outputDir = join(@outputDir, "#{tree[0].name}.#{tree[0].type}")
    @_mkdirp(outputDir)
    plainIndex = 0
    _saveFilesRec = (tree, parentTreeIndex = '') =>
      for d,i in tree
        unless context[d.name]?
          treeIndex = parentTreeIndex + i
          _saveFilesRec(d.deps, treeIndex) if d.deps? and d.deps.length > 0
          name = d.name.replace('/', '.')
          data = if @removeLines 
          then d.data.replace(@requireRegexp, '')
          else d.data
          if @enumerate is "PLAIN"
            fs.writeFileSync(join(outputDir, "#{plainIndex}.#{name}.#{d.type}"), data, 'utf-8')
          else if @enumerate is "TREE"
            fs.writeFileSync(join(outputDir, "#{treeIndex}.#{name}.#{d.type}"), data, 'utf-8')
          else
            fs.writeFileSync(join(outputDir, "#{name}.#{d.type}"), data, 'utf-8')
          plainIndex++
          context[d.name] = yes
    _saveFilesRec(tree)
    return result