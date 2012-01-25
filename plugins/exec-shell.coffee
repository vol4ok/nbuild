###*
* Exec shell commands
*
* @private
* @param name    {String} 
* @param options {Object}  
###

_exec: (name, options) ->
  @_lock()
  oldDir = null
  if options["change-dir"]
    if existsSync(options["change-dir"])
      newDir = fs.realpathSync(options["change-dir"])
      oldDir = process.cwd()
      console.log "change dir to #{newDir}".cyan
      process.chdir(newDir)
    else
      @unlock()
      throw "Error: directory #{options["change-dir"]} not exists"
  n = 0
  console.log 'executing...'.cyan
  async.forEachSeries options.commands
  , (command, callback) -> 
    child_process.exec command, (err, stdout, stderr) ->
      if err is null
        console.log stdout if builder.verbose
        console.log "#{name}[#{n}]: `#{command}` successfully executed!".green
      else
        console.error stderr if builder.verbose
        console.error "Error: exec `#{command}` failed with error \"#{err}\"".red
      n++
      callback(0) 
  , (err) ->
    if oldDir
      process.chdir(oldDir)
    @unlock()