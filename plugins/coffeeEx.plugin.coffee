###!
 * Coffee-Script extended plugin for nBuild
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

jsp    = require("uglify-js").parser
pro    = require("uglify-js").uglify

{join, dirname, basename, extname, normalize, relative, existsSync} = path

REQUIRE_REGEX = /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g

exports.initialize = (builder) -> new CoffeeExPlugin(builder)

class CoffeeExPlugin
  
  ###*
  * @public
  * @constructor
  ###
  constructor: (@builder) ->
    @builder.registerType('coffee-ex', @coffeeEx, this)
    
  coffeeEx: (name, options) -> build_script(script: options, 'output-dir': @builder.defines.PROJECT_DIR)
    
  indexIncludeDirectories = (includeDirs, types, prefix = '') ->
    index = {}
    includeDirs = [includeDirs] unless _.isArray(includeDirs)
    for dir in includeDirs
      for file in fs.readdirSync(dir)
        fullPath = join(dir,file)
        rx = new RegExp("^(.+)\\.(#{types.join('|')})$",'i')
        if rx.test(file)
          t = rx.exec(file)
          name = join(prefix,t[1])
          index[name] = 
            name: name
            type: t[2]
            path: fullPath
        else if fs.statSync(fullPath).isDirectory() and not /^__/.test(file)
          name = join(prefix,file)
          index[name] = 
            name: name
            type: 'dir'
            path: fullPath
          index extends indexIncludeDirectories(fullPath, types, name)
    return index

  parseRequireDirective = (content) ->
    result = []
    content = '\n' + content
    result.push(match[1]) while (match = REQUIRE_REGEX.exec(content)) isnt null
    return result

  findDependencies = (targets, index, opts = {}) ->
    result = []
    targets = [targets] unless _.isArray(targets)
    for target in targets
      if index[target]?
        d = _.clone(index[target])
        d.data = fs.readFileSync(d.path, 'utf8')
        r = parseRequireDirective(d.data)
        d.deps = findDependencies(r, index, opts)
        d.opts = opts
        result.push(d)
        #result = result.concat(t)
      else 
        console.log "Error: #{target} not found".red
    #result = _.uniq(result)
    return result #result.reverse()
    
  compileTree = (tree) ->
    for d in tree
      compileTree(d.deps) if d.deps? and d.deps.length > 0
      if d.type is 'coffee'
        d.data = coffee.compile(d.data, d.opts)
    return tree

  mergeTree = (tree) ->
    context = {}
    _mergeTreeRec = (tree) ->
      code = ''
      for d in tree
        unless context[d.name]?
          code += _mergeTreeRec(d.deps) if d.deps? and d.deps.length > 0
          code += "\n#{d.data}"
          context[d.name] = yes
      return code
    return _mergeTreeRec(tree)
    
  buildList = (list, index, opts) ->
    code = ''
    for t in list
      unless (d = index[t])?
        console.log "ERROR: build prerequired #{t} failed".red
        continue
      if d.type == 'coffee'
        code += coffee.compile(fs.readFileSync(d.path, 'utf-8'), opts)
      else if d.type == 'js'
        code += fs.readFileSync(d.path, 'utf-8')
      else 
        console.log "ERROR: unknown filetype \"#{d.type}\"".red
    return code
    
  mkdir = (path) -> 
    parent = dirname(path)
    mkdir(parent) unless existsSync(parent)
    fs.mkdirSync(path, 0755) unless existsSync(path)
    
  build_script = (options) ->
    @output   = options.script['output-dir'] or options['output-dir']
    @includes = options.script.includes or options.includes
    @resident = options.script.resident or []
    @targets  = options.script.targets or []
    @compress = options.script.compress or options.compress or "no"
    @exts     = options.script.extensions or ["js", "coffee"] #reserved options
    mkdir(@output) unless existsSync(@output)
    index = indexIncludeDirectories(@includes, @exts)
    resident = buildList(@resident, index, {bare: true, utilities: no})
    for target in @targets
      tree = findDependencies(target, index, {bare: true, utilities: no})
      tree = compileTree(tree)
      code = resident + mergeTree(tree)
      if @compress is "yes"
        try
          ast  = jsp.parse(code)
          ast  = pro.ast_mangle(ast)
          ast  = pro.ast_squeeze(ast)
          code = pro.gen_code(ast) 
        catch error
          console.log error
      fullPath = join(@output,"#{target}.js")
      fs.writeFileSync(fullPath, code, 'utf-8')
      console.log "Compile: #{fullPath}".green