require "colors"
fs     = require 'fs'
util   = require 'util'
_      = require 'underscore'
path   = require 'path'
coffee = require 'coffee-sciprt'

###
  options
    require regexp
    include dirs
    file-exts
    targets
    
    output-dir
    
  output:
    file-list: array
###

class RequireParser
  constructor: ->