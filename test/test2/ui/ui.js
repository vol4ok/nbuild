var ClassA, Module1, data, f;

module('ui.module');

include('underscore');

include('jquery');

include('style.styl');

data = __template('build/index.html');

Module1 = require("sm/" + "module");

if (__DEBUG__) console.log(__AUTHOR__, __VERSION__);

f = function() {
  return console.log("ololo");
};

ClassA = (function() {

  ClassA.prototype.A = __precompile(function() {
    return {
      test: 123,
      test2: "24234",
      test3: [1, 2, 3]
    };
  });

  function ClassA() {
    this.temp = require("sm/module");
  }

  ClassA.prototype.method1 = function() {
    return this.Tmpl = __template("index.mu");
  };

  return ClassA;

})();

__extends(exports, {
  ClassA: ClassA
});
