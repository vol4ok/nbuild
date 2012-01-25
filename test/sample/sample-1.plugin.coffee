exports.initialize = (builder) ->
  builder.registerType('test', test)
  test2 = new Test2
  builder.registerType('test2', test2.testMethod, test2)
  
test = ->
  #console.log "Hello world".red
  return 123
  
class Test2
  constructor: ->
    @field = 234
  testMethod: ->
    #console.log "Hello world #{@field}".yellow
    return @field