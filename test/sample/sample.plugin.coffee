exports.initialize = (builder) ->
  console.log 'initalize test plugin'.magenta
  builder.registerType('test', test)
  test2 = new Test2
  builder.registerType('test2', test2.testMethod, test2)
  console.log builder.types
  
test = ->
  console.log "Hello world".red
  
class Test2
  constructor: ->
    @field = 111
  testMethod: ->
    console.log "Hello world #{@field}".yellow