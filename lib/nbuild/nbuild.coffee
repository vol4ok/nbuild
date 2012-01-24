require 'colors'
fs           = require 'fs'
_            = require 'underscore'
path         = require 'path'
OptionParser = require('coffee-script/lib/coffee-script/optparse').OptionParser
Builder      = require('./builder')

{join, existsSync} = path

printLine = (line) -> process.stdout.write line + '\n'

VERSION = "0.1"
BANNER = 'Usage: nbuild [options] command[:step]'
SWITCHES = [
  ['-c', '--config [FILE*]',    'path to .nproj file']
  ['-e', '--environment [ARG]', 'set environment']
  ['-v', '--verbose',           'verbose output']
  ['-V', '--version',           'show version']
  ['-h', '--help',              'display this help message']
]

main = () ->
  optParser  = new OptionParser SWITCHES, BANNER
  o = optParser.parse process.argv[2..]
  
  if o.help
    printLine optParser.help() 
    return
    
  if o.version
    printLine "nbuild v#{VERSION}"
    return
  
  configFiles = []
  
  # добавляем конфиги прописанные фручную
  if o.config?
    for cfg in o.config when existsSync(cfg) 
      configFiles = _.union(configFiles, fs.realpathSync(cfg))
      
  if configFiles.length is 0
    # находим первый .nproj-файл в текущей директории
    for file in fs.readdirSync(process.cwd()) when /\.nproj$/i.test(file)
      configFiles.push fs.realpathSync(join(process.cwd(), file))
      break
      
  if configFiles.length is 0
    printLine "Config wasn't found, read the help for more information `nbuild -h`".yellow
    return
    
  if o.arguments.length is 0
    printLine "Command is not specified, read the help for more information `nbuild -h`".yellow
    return
    
  builderOptions = {}
  builderOptions.verbose     = o.verbose if o.verbose
  builderOptions.environment = o.environment if o.environment
  builderOptions.configFiles = configFiles
  
  try
    builder = new Builder(builderOptions)
    builder.exec(cmd) for cmd in o.arguments
  catch err
    console.log printLine("#{err}".red)
    
main()
