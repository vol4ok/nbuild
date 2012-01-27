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


exports.initialize = (builder) -> new CoffeePlugin(builder)

class CoffeePlugin
  
  ###*
  * @public
  * @constructor
  * @param {Array}  targets
  * @param {Object} [opts] 
  * @param {String} [remove = "no"]
  * @param {String} [recursive = "no"]
  ###
  constructor: (@builder) ->
    @targets = []
    @otps = {}
    @remove  = no
    @recursive = no
    @fileExts = [ "coffee" ]
    @builder.registerType('coffee', @coffee, this)
    
  coffee: (name, options) ->
    throw "Error: `targets` is required attribute" unless options.targets?
    
    @targets   = options.targets
    @fileExts  = options['file-exts'] if options['file-exts']?
    @opts      = options.options if options.options?
    @remove    = options.remove? if options.remove?
    @recursive = options.recursive? if options.recursive?
    
    for target in @targets
      @count = 0
      if fs.lstatSync(target).isDirectory()
        @_compileDir(target)
      else
        @_compileFile(target)
      console.log "compile #{target}: #{@count} files successfully compiled".green
  
  _compileDir: (dir) ->
    for file in fs.readdirSync(dir)
      path = join(dir,file)
      if @recursive and fs.lstatSync(path).isDirectory()
        @_compileDir(path)
      else
        @_compileFile(path)
    
  _compileFile: (infile) ->
    rx = new RegExp("^(.+)\\.(#{@fileExts.join('|')})$", 'i')
    return unless rx.test(infile)
    cs = fs.readFileSync(infile, 'utf-8')
    js = coffee.compile(cs, @opts)
    outfile = join(dirname(infile), "#{basename(infile, extname(infile))}.js")
    @count++
    console.log "compile: #{infile} -> #{outfile}".grey if @builder.verbose
    fs.writeFileSync(outfile, js, 'utf-8')
    if @remove
      fs.unlinkSync(infile) 
      console.log "remove: #{infile}".grey if @builder.verbose