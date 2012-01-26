###!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###
 
 
###* Module dependencies ###

require "colors"
_         = require 'underscore'
CopyFiles = require './copy-files'
path      = require 'path'

{relative} = path

exports.initialize = (builder) -> new CopyHandler(builder)
 
class CopyHandler
  constructor: (@builder) -> 
    @builder.registerType('copy', @copy, this) 
  copy: (name, options) ->
    @builder.lock()
    cp = new CopyFiles options.source, options.destination, 
      replaceStrategy: CopyFiles.REPLACE_OLDER
      on_complete: (stat, cp) =>
        console.log "#{name}: #{stat.filesCopied} files copied".green
        rollback = cp.generateRollback()
        @builder.setState(name, rollback: rollback)
        @builder.unlock()
      on_progress: (ctx, cp) =>
        if @builder.verbose and not ctx.skipped
          console.log "#{relative(process.cwd(), ctx.src)} -> #{relative(process.cwd(), ctx.dst)}".grey