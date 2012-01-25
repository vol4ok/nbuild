var test3;

exports.initialize = function(builder) {
  builder.registerType('test3', test3);
};

test3 = function() {
  //console.log("Hello world".red);
  return 345;
};