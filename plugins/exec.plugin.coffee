###!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###
 
 
###* Module dependencies ###

require "colors"
fs    = require 'fs'
_     = require 'underscore'
path  = require 'path'
async = require 'async'
exec  = require('child_process').exec

{normalize, basename, dirname, extname, join, existsSync, relative} = path

exports.initialize = (builder) -> new ExecHandler(builder)

class ExecHandler
  constructor: (@builder) ->
    @builder.registerType('exec', @exec, this)
  exec: (name, options) ->
    @builder.lock()
    oldDir = null
    if options["change-dir"]
      if existsSync(options["change-dir"])
        newDir = fs.realpathSync(options["change-dir"])
        oldDir = process.cwd()
        console.log "change dir to #{newDir}".cyan
        process.chdir(newDir)
      else
        @builder.unlock()
        throw "Error: directory #{options["change-dir"]} not exists"
    n = 0
    console.log 'executing...'.cyan
    async.forEachSeries options.commands
    , (command, callback) => 
      exec command, (err, stdout, stderr) =>
        if err is null
          console.log stdout if @builder.verbose
          console.log "#{name}[#{n}]: `#{command}` successfully executed!".green
        else
          console.error stderr if @builder.verbose
          console.error "Error: exec `#{command}` failed with error \"#{err}\"".red
        n++
        callback(0) 
    , (err) =>
      if oldDir
        process.chdir(oldDir)
      @builder.unlock()