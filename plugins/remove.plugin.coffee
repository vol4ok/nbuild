require "colors"
_         = require 'underscore'
CopyFiles = require './copy-files'


exports.initialize = (builder) -> new RemoveHandler(builder)

class RemoveHandler
  constructor: (@builder) ->
    @builder.registerType('remove', @remove, this) 
  remove: (name, options) ->
    rm = new RemoveFiles options.items, on_remove: (item) ->
      console.log "remove #{relative(process.cwd(), item)}".grey if @builder.verbose
    console.log "#{name}: #{rm.statistics.filesRemoved} files removed".green