command line examples
nbuild 
  -c — nproj file
  -e — enveroument
  -d — verbose
  -v — version
  
bundle

copy
  source
  destination
  filter {
    allow
    deny
    allow-ext
    deny-ext
  }
  
remove
  targets
  filter {
    allow
    deny
    allow-ext
    deny-ext
  }
  
exec
  commands
  change-dir
  save-stdout
  save-stderr
  
exec-task
  task
  
rollback
  step
  
require
  targets []
  output-var
  output-dir
  
coffee-script
  targets []
  filter {
    allow
    deny
    allow-ext
    deny-ext
  }
  output-var
  output-dir
  
less

merge

reserver words
@environment — default environment
@defines     — defines constants and variables
@defaults    — set default key values
@type

используемые теги в доках

@param
@return
@api {public|private}
@class
@constructor
@private
@public

