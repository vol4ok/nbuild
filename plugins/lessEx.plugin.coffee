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
less   = require 'less'

{join, dirname, basename, extname, normalize, relative, existsSync} = path

REQUIRE_REGEX = /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g

exports.initialize = (builder) -> new LessExPlugin(builder)

class LessExPlugin
  
  ###*
  * @public
  * @constructor
  ###
  constructor: (@builder) ->
    @builder.registerType('less-ex', @lessEx, this)
    
  lessEx: (name, options) -> 
    @builder.lock()
    build_style 
      style: options, 
      outputDir: @builder.defines.PROJECT_DIR
    , =>
      @builder.unlock()
    
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
    
  mergeTreeEx = (tree, type) ->
    context = {}
    _mergeTreeRec = (tree) ->
      code = ''
      for d in tree
        unless context[d.name]?
          code += _mergeTreeRec(d.deps) if d.deps? and d.deps.length > 0
          code += "\n#{d.data}" if d.type is type
          context[d.name] = yes
      return code
    return _mergeTreeRec(tree)
    
  buildLess = (str, options, callback) ->
    parser = new less.Parser
      paths: options.includes
      filename: options.output
    parser.parse str, (err, tree) ->
      if err
        console.error err 
        callback(err)
      css = tree.toCSS(compress: options.compress)
      callback(err,css)
    
  build_style = (options, callback) ->
    @output   = options.style.outputDir or options.outputDir
    @includes = options.style.includes or options.includes
    @targets  = options.style.targets or []
    @compress = options.style.compress or options.compress or no
    @exts     = options.style.extensions or ["css", "less"] #reserved options
    mkdir.sync(@output, "0755") unless existsSync(@output)
    index = indexIncludeDirectories(@includes, @exts)
    for s in @targets
      output = join(@output, "#{s}.css")
      style_opt = 
        includes: @includes
        compress: @compress
        output: @output
      tree = findDependencies(s, index, style_opt)
      _less = mergeTreeEx(tree,'less')
      css = mergeTreeEx(tree,'css')
      buildLess _less, style_opt, (err, result) ->
        css += '\n' + result
        fs.writeFileSync(output, css, 'utf-8')
        console.log "Compile: #{output}".green
        callback(err)
    return