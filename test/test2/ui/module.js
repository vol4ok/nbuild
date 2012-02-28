var ClassB;

ClassB = (function() {

  function ClassB() {}

  ClassB.prototype.method1 = function() {
    return this.tmp = template("ClassB.mu");
  };

  return ClassB;

})();

__extends(exports, {
  ClassB: ClassB
});
