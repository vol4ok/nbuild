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

{join, dirname, basename, extname, normalize, relative, existsSync} = path

REQUIRE_REGEX = /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g

exports.initialize = (builder) -> new CoffeekupPlugin(builder)

class CoffeekupPlugin
  
  ###*
  * @public
  * @constructor
  ###
  constructor: (@builder) ->
    @builder.registerType('coffeekup', @coffeekup, this)
    
  coffeekup: (name, options) -> 
    build_view(view: options, 'output-dir': @builder.defines.PROJECT_DIR)
  
  build_view = (options) ->
    return unless options.view?
    @builder = options.view.builder
    @output  = options.view['output-dir'] or options['output-dir']
    @targets = options.view.targets or []
    mkdir.sync(@output, "0755") unless existsSync(@output)
    builder = require(@builder)
    for target in @targets
      fullPath = join(@output, "#{target}.html")
      fs.writeFileSync(fullPath, builder[target](), 'utf-8')
      console.log "Compile: #{fullPath}".green