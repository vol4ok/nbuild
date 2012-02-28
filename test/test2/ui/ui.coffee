module 'ui.module'
include 'underscore'
include 'jquery'
include 'style.styl'

data = __template 'build/index.html'


Module1 = require "sm/"+"module"

console.log __AUTHOR__, __VERSION__ if __DEBUG__

f = () -> console.log "ololo"

class ClassA
  A: __precompile -> return {test: 123, test2: "24234", test3: [1,2,3]}
  constructor: ->
    @temp = require "sm/module"
  method1: ->
    @Tmpl = __template "index.mu"
    
exports extends {ClassA}