vows      = require 'vows'
assert    = require 'assert'
async     = require 'async'
fs        = require 'fs'
path      = require 'path'
exec      = require('child_process').exec
CopyFiles = require '../lib/nbuild/copy-files'

{normalize, basename, dirname, extname, join, existsSync, relative} = path

ALPHABET = 'abcdefghijklmnopqrstuvwxyz0123456789'.split('')
SRC_DIR  = '/tmp/test-copy-files/src'
DST_DIR  = '/tmp/test-copy-files/dst'
NUM_OF_FILES = 5
FILE_SIZE_LIMIT = 1000

rand = (n) -> Math.floor(Math.random()*n)

generateName = (alphabet, length) ->
  name = ""
  for i in [0...length]
    name += alphabet[rand(alphabet.length)]
  return name
  
mkdirp = (path, mode = 0755) ->
  return 
  parent = dirname(path)
  mkdirp(parent, mode) unless existsSync(parent)
  fs.mkdirSync(path, mode) unless existsSync(path)

cleanDir = (path) ->
  for f in fs.readdirSync(path)
    fs.unlinkSync(join(path,f))
  
generateFiles = (dir, count, maxSize, callback) ->
  files = []
  for i in [0...count]
    files.push join(dir, generateName(ALPHABET, 10))
  async.forEach files, (file, cb) -> 
    exec "dd if=/dev/urandom of=#{file} bs=1 count=#{rand(maxSize)}", cb
  , callback
  return files

mkdirp(SRC_DIR)
mkdirp(DST_DIR)

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
}).export(module)