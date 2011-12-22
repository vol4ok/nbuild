class CoffeeCompiller extends Compiller
  constructor: (options) ->
    options.types = 
    super(options)
    
  compile: ->
    return unless options.script?
    @output   = options.script['output-dir'] or options['output-dir']
    @includes = options.script.includes or options.includes
    @resident = options.script.resident or []
    @targets  = options.script.targets or []
    @compress = options.script.compress or options.compress or "no"
    @exts     = options.script.extensions or ["js", "coffee"] #reserved options
    mkdir.sync(@output, "0755") unless existsSync(@output)
    index = @indexIncludeDirs(@includes, @exts)
    resident = buildList(@resident, index, {bare: true, utilities: no})
    for target in @targets
      tree = findDependencies(target, index, {bare: true, utilities: no})
      tree = compileTree(tree)
      code = resident + mergeTree(tree)
      if @compress is "yes"
        try
          ast = jsp.parse(code)
          ast = pro.ast_mangle(ast)
          ast = pro.ast_squeeze(ast)
          code = pro.gen_code(ast) 
        catch error
          console.log error
      fullPath = join(@output,"#{target}.js")
      fs.writeFileSync(fullPath, code, 'utf-8')
      console.log "Compile: #{fullPath}".green