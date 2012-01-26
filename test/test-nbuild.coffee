###!
* nBuild
* Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
* MIT Licensed
###

###* Module dependencies ###

require 'colors'
vows      = require 'vows'
assert    = require 'assert'
async     = require 'async'
fs        = require 'fs'
path      = require 'path'
exec      = require('child_process').exec
helpers   = require '../lib/nbuild/helpers'

{normalize, basename, dirname, extname, join, existsSync, relative} = path
{rand, generateName, mkdirp, cleanDir, generateFiles} = helpers

WORK_DIR = fs.realpathSync('sample/test-project-1')

vows.describe('Builder').addBatch({
  'prepare': 
    topic: ->
      exec "./../bin/nbuild -c #{WORK_DIR}/test-1.nproj prepare", @callback
      return undefined
    'dst folder should be deleted': (err, stdout, stderr) ->
      assert.isFalse(existsSync("#{WORK_DIR}/dst"))
}).addBatch({
  'test copy': 
    topic: ->
      exec './../bin/nbuild -c sample/test-project-1/test-1.nproj test:copy', @callback
      return undefined
    'files should be copied': (err, stdout, stderr) ->
      assert.isTrue(existsSync("#{WORK_DIR}/dst"))
      assert.isTrue(existsSync("#{WORK_DIR}/dst/file-1.txt"))
      assert.isTrue(existsSync("#{WORK_DIR}/dst/file-2.txt"))
      assert.isTrue(existsSync("#{WORK_DIR}/dst/file-3.txt"))
    'should show success message': (err, stdout, stderr) ->
      assert.match(stdout, /copy: 3 files copied/i)
  'test exec': 
    topic: ->
      exec './../bin/nbuild -v -c sample/test-project-1/test-1.nproj test:exec', @callback
      return undefined
    'should show `Hello world` message': (err, stdout, stderr) ->
      assert.match(stdout, /Hello world/)
    'should executed in project dir': (err, stdout, stderr) ->
      assert.match(stdout, RegExp("#{WORK_DIR}"))
  'test batch': 
    topic: ->
      exec './../bin/nbuild -v -c sample/test-project-1/test-1.nproj test:batch', @callback
      return undefined
    'should be show files in `src` dir': (err, stdout, stderr) ->
      assert.match(stdout.replace(/\n/gm,""), /file-1\.txt.*file-2\.txt.*file-3\.txt/)
  'test call': 
    topic: ->
      exec './../bin/nbuild -v -c sample/test-project-1/test-1.nproj test:call', @callback
      return undefined
    'should be show files in `src` dir': (err, stdout, stderr) ->
      assert.match(stdout.replace(/\n/gm,""), /file-1\.txt.*file-2\.txt.*file-3\.txt/)
}).addBatch({
  'test remove': 
    topic: ->
      exec './../bin/nbuild -c sample/test-project-1/test-1.nproj test:remove', @callback
      return undefined
    'files should be copied': (err, stdout, stderr) ->
      assert.isTrue(existsSync("#{WORK_DIR}/dst"))
      assert.isFalse(existsSync("#{WORK_DIR}/dst/file-1.txt"))
    'should show success message': (err, stdout, stderr) ->
      assert.match(stdout, /remove: 1 files removed/i)
  'test rollback': 
    topic: ->
      exec './../bin/nbuild -c sample/test-project-1/test-1.nproj test:rollback', @callback
      return undefined
    'files should be removed': (err, stdout, stderr) ->
      assert.isFalse(existsSync("#{WORK_DIR}/dst"))
      assert.isFalse(existsSync("#{WORK_DIR}/dst/file-2.txt"))
      assert.isFalse(existsSync("#{WORK_DIR}/dst/file-3.txt"))
}).export(module)