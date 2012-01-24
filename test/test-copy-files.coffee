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
CopyFiles = require '../lib/nbuild/copy-files'
helpers   = require '../lib/nbuild/helpers'

{rand, generateName, mkdirp, cleanDir, generateFiles} = helpers
{normalize, basename, dirname, extname, join, existsSync, relative} = path

ALPHABET = 'abcdefghijklmnopqrstuvwxyz0123456789'.split('')
SRC_DIR  = '/tmp/test-copy-files/src'
DST_DIR  = '/tmp/test-copy-files/dst'
NUM_OF_FILES = 20
FILE_SIZE_LIMIT = 1000

g_createdDirs = []

mkdirp(SRC_DIR, 0755, g_createdDirs)
mkdirp(DST_DIR, 0755, g_createdDirs)

vows.describe('copy-files').addBatch({
  'basic copy':
    topic: -> 
      cleanDir(SRC_DIR)
      cleanDir(DST_DIR)
      generateFiles SRC_DIR, NUM_OF_FILES, FILE_SIZE_LIMIT, @callback
      return undefined
    'after generate':
      topic: ->
        cp = new CopyFiles SRC_DIR, DST_DIR, 
          replaceStrategy: CopyFiles.REPLACE
          on_complete: @callback
        return undefined
      'check files count': (stat, cp) -> 
        assert.equal fs.readdirSync(DST_DIR).length, fs.readdirSync(SRC_DIR).length
      'check presence of files': (stat, cp) -> 
        for f in fs.readdirSync(SRC_DIR)
          assert.isTrue(existsSync(join(DST_DIR, f)))
      'check files size': (stat, cp) -> 
        for f in fs.readdirSync(SRC_DIR)
          srcStat = fs.lstatSync(SRC_DIR)
          dstStat = fs.lstatSync(DST_DIR)
          assert.equal srcStat.size, dstStat.size
}).addBatch({
  'clean': 
    topic: ->
      cleanDir(SRC_DIR)
      cleanDir(DST_DIR)
      while g_createdDirs.length > 0
        fs.rmdirSync(g_createdDirs.pop())
    'cleaned': ->
}).export(module)