require "colors"
fs   = require 'fs'
util = require 'util'
_    = require 'underscore'
path = require 'path'

{normalize, basename, dirname, extname, join, existsSync} = path

class CopyFiles
  defaults: 
    copyFileTimestamp: yes
    replaceStrategy: REPLACE_OLDER
    on_progress: null
    on_complete: null
  numOfOpenFiles: 0
  maxNumOfOpenFiles: 100
  
  # for internal use
  STATUS_SUCCESS = 0
  STATUS_PENDING = 1
  STATUS_FAIL    = -1
  
  # for export
  STATUS_SUCCESS: STATUS_SUCCESS
  STATUS_FAIL :   STATUS_FAIL
  
  # for internal use
  REPLACE       = 0
  SKIP          = 1
  REPLACE_OLDER = 2
  
  # for export
  REPLACE:       REPLACE
  SKIP:          SKIP
  REPLACE_OLDER: REPLACE_OLDER
  
  constructor: (src, dst, options) ->
    throw "Error: #{src} not found!" unless existsSync(src)
    @options = _.extend {}, @defaults, options
    @contextList = []
    @statistics = 
      dirsCopied: 0
      filesCopied: 0
      dirsRequested: 0
      filesRequested: 0
      filesSkipped: 0
      errors: 0
      totalSize: 0
      copiedSize: 0
    @transferQueue = []
    src = normalize(src)
    dst = normalize(dst)
    @_copy(src, dst, _.bind(@_complete, this))
  _complete: (status) ->
    @options.on_complete(this) if _.isFunction(@options.on_complete)
    
  generateRollback: () ->
    rollback = []
    ctxList = @contextList
    _genRollback = (ctx) ->
      for id in ctx.child
        _genRollback(ctxList[id])
      if ctx.folder
      then rollback.push(command: "rmdir", path: ctx.dst)
      else rollback.push(command: "rm"   , path: ctx.dst)
    _genRollback(ctxList[0])
    return rollback
    
  _makeDir: (path, ctx = null, mode = 0755) ->
    parent = dirname(path)
    unless existsSync(parent)
      return false unless @_makeDir(parent, ctx, mode)
    return false unless @_mkdirSync(path, mode)
    ctx.createdFolders.push(path) if ctx?
    return true
    
  _copy: (src, dst, callback) ->
    #throw "Error: #{src} not found!" unless existsSync(src)
    ctx = 
      id: @contextList.length
      src: src
      dst: dst
      lock: yes
      complete: no
      status: STATUS_SUCCESS
      copied: 0
      copying: 0
      errors: 0
      replace: no
      callback: callback
      child: []
      createdFolders: []
      
    ctx.status = (=> 
      return STATUS_FAIL unless ctx.srcAttr = @_lstatSync(src)        
      ctx.folder = ctx.srcAttr.isDirectory()
      
      if ctx.exists = existsSync(dst)
        return STATUS_FAIL unless ctx.dstAttr = @_lstatSync(dst)  
        
      @contextList.push(ctx)
        
      if ctx.folder
        unless ctx.exists
          return STATUS_FAIL unless @_makeDir(dst, ctx)
            
        @statistics.dirsRequested++
        files = @_readdirSync(src)
        return STATUS_FAIL unless files
        for file in files
          newSrc = join(src,file)
          newDst = join(dst,file)
          ctx.copying++
          ctx.child.push @_copy(newSrc, newDst, (err) => @_copyCompletetion(err, ctx)).id
      else
        dstDir = dirname(dst)
        unless existsSync(dstDir)
          return STATUS_FAIL unless @_makeDir(dstDir, ctx)
        @statistics.filesRequested++
        @statistics.totalSize += ctx.srcAttr.size
        ctx.copying++
        if ctx.exists
          switch @options.replaceStrategy
            when SKIP
              @_copyCompletetion(STATUS_SUCCESS, ctx)
              return STATUS_SUCCESS
            when REPLACE_OLDER
              if ctx.srcAttr.mtime.getTime() <= ctx.dstAttr.mtime.getTime()
                @_copyCompletetion(STATUS_SUCCESS, ctx)
                return STATUS_SUCCESS 
              else
                ctx.replace = yes
            else
              ctx.replace = yes
        if @numOfOpenFiles < @maxNumOfOpenFiles
        then @_transferFile(ctx, (err) => @_copyCompletetion(0, ctx))
        else @transferQueue.push(=> @_transferFile(ctx, (err) => @_copyCompletetion(0, ctx)))
      
      return if ctx.coping > 0 then STATUS_PENDING else STATUS_SUCCESS
    )()
    ctx.lock = no
    if ctx.complete = ctx.copying is 0 and not ctx.lock
      ctx.callback(ctx.status, ctx)
        
    return ctx

  _transferFile: (ctx, callback) ->
    @numOfOpenFiles++
    srcStream = @_createReadStream(ctx.src)
    dstStream = @_createWriteStream(ctx.dst)
    callback(STATUS_FAIL) unless srcStream or dstStream
    util.pump(srcStream, dstStream, callback)
    
  _copyCompletetion: (err, ctx) ->
    skiped = ctx.exists and not ctx.replace
    unless ctx.folder or skiped
      @numOfOpenFiles--;
      while @transferQueue.length > 0 and @numOfOpenFiles < @maxNumOfOpenFiles
        @transferQueue.shift()()
    
    if @options.copyFileTimestamp and not err and not skiped
      fs.utimesSync(ctx.dst, ctx.srcAttr.atime, ctx.srcAttr.mtime)
    
    if err == STATUS_FAIL
      ctx.errors++
      @statistics.errors++
      ctx.status = STATUS_FAIL
    else
      ctx.status = STATUS_SUCCESS
      ctx.copied++
      if ctx.folder
        @statistics.dirsCopied++
      else
        if skiped
          @statistics.filesSkipped++
        else
          @statistics.filesCopied++
          @statistics.copiedSize += ctx.srcAttr.size
          
    if @options.on_progress? and _.isFunction(@options.on_progress)
      @options.on_progress(ctx)
      
    if --ctx.copying is 0 and not ctx.lock
      ctx.callback(ctx.status)
          
  _readdirSync: (path) ->
    try
      return fs.readdirSync(path)
    catch err
      if err.code is 'EACCES'
        console.log "Error: no access to #{path}".red
        return false
      throw err
  _createReadStream: (path) ->
    try
      return fs.createReadStream(path)
    catch err
      if err.code is 'EACCES'
        console.log "Error: no access to #{path}".red
        return false
      throw err
  _createWriteStream: (path) ->
    try
      return fs.createWriteStream(path)
    catch err
      if err.code is 'EACCES'
        console.log "Error: no access to #{path}".red
        return false
      throw err
  _lstatSync: (path) ->
    try
      return fs.lstatSync(path)
    catch err
      if err.code is 'EACCES'
        console.log "Error: no access to #{path}".red
        return false
      throw err
  _mkdirSync: (path) ->
    try
      fs.mkdirSync(path)
    catch err
      if err.code is 'EACCES'
        console.log "Error: no access to #{path}".red
        return false
      throw err
    return true

module.exports = CopyFiles