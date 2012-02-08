###!
 * Coffee-Script template plugin for nBuild
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


exports.initialize = (builder) -> new CoffeeTemplatePlugin(builder)

class CoffeeTemplatePlugin
  
  ###*
  * @public
  * @constructor
  * @param {String} target
  * @param {String} output
  * @param {Object} [params]
  ###
  
  constructor: (@builder) ->
    @target  = ""
    @output  = null
    @params  = {}
    @builder.registerType('coffee-template', @coffeeTemplate, this)
    
  coffeeTemplate: (name, options) ->
    throw "Error: `target` is required attribute" unless options.target?
    
    @target   = options.target
    @output   = options.output or join(dirname(@target), basename(@target, extname(@target)))
    @params   = options.params if options.params?
        
    require.extensions[extname(@target)] = (module, filename) ->
      content = coffee.compile(fs.readFileSync(filename, 'utf8'), {filename})
      module._compile content, filename
      
    cfg = require(join(@builder.defines.PROJECT_DIR, @target))(@params)
    fs.writeFileSync(@output, cfg, 'utf-8')