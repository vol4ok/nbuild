###!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
###

###* Module dependencies ###

require 'colors'
fs             = require 'fs'
_              = require 'underscore'
path           = require 'path'
{OptionParser} = require 'coffee-script/lib/coffee-script/optparse'
Builder        = require './nbuild'
require 'coffee.nbplug'

{join, existsSync} = path

VERSION = "0.3.0"
BANNER = 'Usage: nbuild [options] command[:step]'
SWITCHES = [
  ['-c', '--config [FILE*]',    'path to .nproj file']
  ['-e', '--environment [ARG]', 'set environment']
  ['-v', '--verbose',           'verbose output']
  ['-V', '--version',           'show version']
  ['-p', '--plugin [FILE*]',    'add plugin file or dir']
  ['-h', '--help',              'display this help message']
]

STANDARD_PLUGIN_DIR = "#{__dirname}/../plugins"

###* Entry point ###

main = () ->
  optParser  = new OptionParser SWITCHES, BANNER
  o = optParser.parse process.argv[2..]
  
  if o.help
    console.log optParser.help() 
    return
    
  if o.version
    console.log "nbuild v#{VERSION}"
    return
  
  configFiles = []
  
  # добавляем конфиги прописанные фручную
  if o.config?
    for cfg in o.config when existsSync(cfg) 
      configFiles = _.union(configFiles, fs.realpathSync(cfg))
      
  if configFiles.length is 0
    # находим первый .nproj-файл в текущей директории
    for file in fs.readdirSync(process.cwd()) when /\.nbproj$/i.test(file)
      configFiles.push fs.realpathSync(join(process.cwd(), file))
      break
      
  if configFiles.length is 0
    console.log "Config wasn't found, read the help for more information `nbuild -h`".yellow
    return
    
  if o.arguments.length is 0
    console.log "Command is not specified, read the help for more information `nbuild -h`".yellow
    return
    
  plugins = [ STANDARD_PLUGIN_DIR ]
  plugins = plugins.concat(o.plugins) if o.plugins
  
  builderOptions = {}
  builderOptions.verbose     = o.verbose if o.verbose
  builderOptions.environment = o.environment if o.environment
  builderOptions.plugins     = plugins
  builderOptions.configFiles = configFiles
  
  #try
  builder = new Builder(builderOptions)
  builder.exec(cmd) for cmd in o.arguments
  #catch err
  #  console.log "#{err}".red
    
main()
