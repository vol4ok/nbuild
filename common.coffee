class Compiller
  REQUIRE_REGEX: /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g
  
  constructor: (options) ->
    @index = {}
    @includes = options.includes
    @types    = options.types
    
  indexIncludeDirs: (includeDirs, prefix = '') ->
    includeDirs = [includeDirs] unless _.isArray(includeDirs)
    for dir in includeDirs
      for file in fs.readdirSync(dir)
        fullPath = join(dir,file)
        rx = new RegExp("^(.+)\\.(#{@types.join('|')})$",'i')
        if rx.test(file)
          m = rx.exec(file)
          name = join(prefix,m[1])
          @index[name] = {name: name, type: m[2], path: fullPath}
        else if fs.statSync(fullPath).isDirectory() and not /^__/.test(file)
          name = join(prefix,file)
          @index[name] = {name: name, type: 'dir', path: fullPath}
          @index extends @indexIncludeDirs(fullPath, name)
    return @index
    
  parseRequireDirective: (content) ->
    result = []
    content = '\n' + content
    result.push(m[1]) while (m = @REQUIRE_REGEX.exec(content)) isnt null
    return result

  findDependencies: (targets) ->
    result = []
    targets = [targets] unless _.isArray(targets)
    for target in targets
      if @index[target]?
        d = _.clone(@index[target])
        d.data = fs.readFileSync(d.path, 'utf8')
        r = @parseRequireDirective(d.data)
        d.deps = @findDependencies(r, opts)
        d.opts = @compillerOptions
        result.push(d)
      else 
        console.log "Error: #{target} not found".red
    return result