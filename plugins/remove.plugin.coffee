###!
 * remove plugin for nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###
 
 
###* Module dependencies ###

require "colors"
_           = require 'underscore'
RemoveFiles = require './remove-files'
path        = require 'path'

{relative} = path

exports.initialize = (builder) -> new RemovePlugin(builder)

class RemovePlugin
  constructor: (@builder) ->
    @builder.registerType('remove', @remove, this) 
  remove: (name, options) ->
    rm = new RemoveFiles options.items, on_remove: (item) =>
      console.log "remove #{relative(process.cwd(), item)}".grey if @builder.verbose
    console.log "#{name}: #{rm.statistics.filesRemoved} files removed".green