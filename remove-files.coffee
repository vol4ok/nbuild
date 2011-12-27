require "colors"
fs   = require 'fs'
util = require 'util'
_    = require 'underscore'
path = require 'path'

{normalize, basename, dirname, extname, join, existsSync} = path

class RemoveFiles
  defaults: {}
  constructor: (items, options) ->
    @options = _.extend {}, @defaults, options
    @statistics = 
      filesRequested: 0
      dirsRequested: 0
      filesRemoved: 0
      dirsRemoved: 0
      errors: 0
    @remove(items) if items?
    
  remove: (items) ->
    _items = []
    for item in items 
      _items.push fs.realpathSync(item) if existsSync(item)
    for item in _items
      if fs.lstatSync(item).isDirectory()
        @statistics.dirsRequested++
        t = _.map(fs.readdirSync(item), (name) -> join(item, name))
        @remove(t)
        try
          fs.rmdirSync(item)
          @statistics.dirsRemoved++
          @options.on_remove(item, this) if _.isFunction(@options.on_remove)
        catch err
          @statistics.errors++
          console.warn "Warning: can't delete dir #{item}".yellow
      else
        @statistics.filesRequested++
        try
          fs.unlinkSync(item)
          @statistics.filesRemoved++
          @options.on_remove(item, this) if _.isFunction(@options.on_remove)
        catch err
          @statistics.errors++
          console.warn "Warning: can't delete file #{item}".yellow
  
module.exports = RemoveFiles