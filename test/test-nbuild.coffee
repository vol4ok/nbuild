###!
* nBuild
* Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
* MIT Licensed
###

###* Module dependencies ###

vows      = require 'vows'
assert    = require 'assert'
async     = require 'async'
fs        = require 'fs'
path      = require 'path'
exec      = require('child_process').exec
helpers   = require '../lib/nbuild/helpers'

{normalize, basename, dirname, extname, join, existsSync, relative} = path
{rand, generateName, mkdirp, cleanDir, generateFiles} = helpers

vows.describe('Builder').addBatch({
  'test copy': ->
})