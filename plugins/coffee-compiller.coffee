require "colors"
fs     = require 'fs'
util   = require 'util'
_      = require 'underscore'
path   = require 'path'
coffee = require 'coffee-sciprt'

{normalize, basename, dirname, extname, join, existsSync} = path

###
  1) require parser
  2) compiller
  3) merger
  4) compressor
###

class CoffeeCompiller
  initialize: ->