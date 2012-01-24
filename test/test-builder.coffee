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
Builder   = require '../lib/nbuild/builder'
helpers   = require '../lib/nbuild/helpers'

{normalize, basename, dirname, extname, join, existsSync, relative} = path
{rand, generateName, mkdirp, cleanDir, generateFiles} = helpers

WORK_DIR = "#{__dirname}/sample"

g_createdDirs = []

mkdirp(WORK_DIR, 0755, g_createdDirs)

vows.describe('builder').addBatch({
  'load config':
    topic: ->
      return new Builder 
        environment: 'production'
        configFiles: [ join(WORK_DIR,'config-1.nproj') ]
    'config should be loaded': (builder) ->
      assert.isObject(builder.config)
      assert.isObject(builder.config.test)
      assert.equal(builder.config['@environment'], 'development')
    'setting environment manually': (builder) ->
      assert.equal(builder.environment, 'production')
    'builder should be unlocked': (builder) ->
      assert.isFalse(builder.lock)
  'load multiple config':
    topic: ->
      return new Builder 
        environment: 'test'
        configFiles: [ join(WORK_DIR,'config-1.nproj'), join(WORK_DIR,'config-2.nproj') ]
    'config should be loaded': (builder) ->
      assert.isObject(builder.config)
      assert.isObject(builder.config.test)
      assert.equal(builder.config['@environment'], 'production')
    'setting environment manually': (builder) ->
      assert.equal(builder.environment, 'test')
    'same fields should be overwritten': (builder) ->
      assert.deepEqual(builder.config.test["overwrite-test-1"], {})
      assert.equal(builder.config.test["overwrite-test-2"], 2)
      assert.equal(builder.config.test["overwrite-test-3"], "2")
      assert.deepEqual(builder.config.test["overwrite-test-4"], [2,"3"])
      assert.deepEqual(builder.config.test["overwrite-test-5"], {"test":"1", "tset": "2"})
  # 'parse defines':
  # 'parse defaults':
  # 'detect environment':
  # 'state':
  # 'async lock':
}).export(module)