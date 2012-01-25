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

WORK_DIR    = "#{__dirname}/sample"
CURRENT_DIR = process.cwd()

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
  'parse defines and defaults':
    topic: ->
      return new Builder 
        configFiles: [ join(WORK_DIR,'config-3.nproj') ]
    'PROJECT_NAME should be set': (builder) ->
      assert.equal(builder.defines.PROJECT_NAME, 'config-3')
    'PROJECT_DIR should be set': (builder) ->
      assert.equal(builder.defines.PROJECT_DIR, WORK_DIR)
    'CURRENT_DIR should be set': (builder) ->
      assert.equal(builder.defines.CURRENT_DIR, CURRENT_DIR)
    'check string variables': (builder) ->
      assert.equal(builder.defines.define_0, "#{WORK_DIR}/#{CURRENT_DIR}/config-3/test")
      assert.equal(builder.defines.define_1, 1)
      assert.equal(builder.defines.define_2, '2')
      assert.equal(builder.defines.define_3, '21')
      assert.equal(builder.defines.define_4, '42')
      assert.equal(builder.defaults.default_0, "#{WORK_DIR}/#{CURRENT_DIR}/config-3/test")
      assert.equal(builder.defaults.default_1, 1)
      assert.equal(builder.defaults.default_2, '2')
      assert.equal(builder.defaults.default_3, '21')
      assert.equal(builder.defaults.default_4, '42')
    'check object variables': (builder) ->
      assert.deepEqual(builder.defines.define_5, [ 5, '5', '521', '52142' ])
      assert.deepEqual(builder.defines.define_6, { '2': '21', test1: '621' })
      assert.deepEqual(builder.defines.define_7, [ 5, '5', '521', '52142' ])
      assert.deepEqual(builder.defines.define_8, { '2': '21', test1: '621' })
      assert.equal(builder.defines.define_9, '{"2":"21","test1":"621"}')
      assert.equal(builder.defines.define_10, '@(define_6)_' )
      assert.deepEqual(builder.defaults.default_5, [ 5, '5', '521', '52142' ])
      assert.deepEqual(builder.defaults.default_6, { '2': '21', test1: '621' })
      assert.deepEqual(builder.defaults.default_7, [ 5, '5', '521', '52142' ])
      assert.deepEqual(builder.defaults.default_8, { '2': '21', test1: '621' })
      assert.equal(builder.defaults.default_9, '{"2":"21","test1":"621"}')
      assert.equal(builder.defaults.default_10, '@(define_6)_' )
    'check escaped variable': (builder) ->
      assert.equal(builder.defines.define_11, '12\\$(define_2)')
      assert.equal(builder.defines.define_12, '12\\\\2')
      assert.equal(builder.defaults.default_11, '12\\$(define_2)')
      assert.equal(builder.defaults.default_12, '12\\\\2')
    'load plugin':
      topic: -> new Builder 
        configFiles: [ join(WORK_DIR,'config-3.nproj') ]
        pluginsDir: [ '/Users/Andrew/Sites/projects/nbuild/test/sample' ]
      'test plugin': (builder) ->
        builder.types.test()
        builder.types.test2()
  # 'detect environment':
  # 'state':
  # 'async lock':
}).export(module)