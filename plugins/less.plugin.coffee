###!
 * LESS plugin for nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###


###* Module dependencies ###

require "colors"
fs     = require 'fs'
util   = require 'util'
_      = require 'underscore'
async  = require 'async'
less   = require 'less'
path   = require 'path'
coffee = require 'coffee-script'

{join, dirname, basename, extname, normalize, relative, existsSync} = path


exports.initialize = (builder) -> new LessPlugin(builder)

class LessPlugin
  
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
    @includes = []
    @outputDir = null
    @compress = false
    @builder.registerType('less', @less, this)
    
  less: (name, options) ->
    throw "Error: `targets` is required attribute" unless options.targets?
    throw "Error: `output-dir` is required attribute" unless options["output-dir"]
    
    @targets   = options.targets
    @outputDir = options["output-dir"]
    @includes  = options["include-dirs"] if _.isArray(options["include-dirs"])
    @compress  = options.compress if options.compress?
    
    @_mkdirp(@outputDir)
    @outputDir = fs.realpathSync(@outputDir)
    
    @includes = _.map @includes, (inc) -> fs.realpathSync(inc)
        
    @count = 0
    @builder.lock()
    async.forEach @targets, _.bind(@_parseLess, this), (err) => 
      @builder.unlock()
      console.log "compile: #{@count} files successfully compiled".green
      
  _parseLess: (infile, callback) ->
    lss = fs.readFileSync(infile, 'utf-8')
    outfile = join(@outputDir, "#{basename(infile, extname(infile))}.css")
    parser = new less.Parser
      paths: @includes
      filename: outfile
    parser.parse lss, (err, tree) =>
      if err
        console.error err 
        callback(err)
        return
      css = tree.toCSS(compress: @compress)
      fs.writeFileSync(outfile, css, 'utf-8')
      @count++
      console.log "write: #{outfile}".grey if @builder.verbose
      callback(err)
    
  _mkdirp: (path, mode = 0755) -> 
    parent = dirname(path)
    @_mkdirp(parent, mode) unless existsSync(parent)
    fs.mkdirSync(path, mode) unless existsSync(path)