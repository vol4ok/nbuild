var Compiller,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

Compiller = (function() {

  Compiller.prototype.REQUIRE_REGEX = /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g;

  function Compiller(options) {
    this.index = {};
    this.includes = options.includes;
    this.types = options.types;
  }

  Compiller.prototype.indexIncludeDirs = function(includeDirs, prefix) {
    var dir, file, fullPath, m, name, rx, _i, _j, _len, _len2, _ref;
    if (prefix == null) prefix = '';
    if (!_.isArray(includeDirs)) includeDirs = [includeDirs];
    for (_i = 0, _len = includeDirs.length; _i < _len; _i++) {
      dir = includeDirs[_i];
      _ref = fs.readdirSync(dir);
      for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
        file = _ref[_j];
        fullPath = join(dir, file);
        rx = new RegExp("^(.+)\\.(" + (this.types.join('|')) + ")$", 'i');
        if (rx.test(file)) {
          m = rx.exec(file);
          name = join(prefix, m[1]);
          this.index[name] = {
            name: name,
            type: m[2],
            path: fullPath
          };
        } else if (fs.statSync(fullPath).isDirectory() && !/^__/.test(file)) {
          name = join(prefix, file);
          this.index[name] = {
            name: name,
            type: 'dir',
            path: fullPath
          };
          __extends(this.index, this.indexIncludeDirs(fullPath, name));
        }
      }
    }
    return this.index;
  };

  Compiller.prototype.parseRequireDirective = function(content) {
    var m, result;
    result = [];
    content = '\n' + content;
    while ((m = this.REQUIRE_REGEX.exec(content)) !== null) {
      result.push(m[1]);
    }
    return result;
  };

  Compiller.prototype.findDependencies = function(targets) {
    var d, r, result, target, _i, _len;
    result = [];
    if (!_.isArray(targets)) targets = [targets];
    for (_i = 0, _len = targets.length; _i < _len; _i++) {
      target = targets[_i];
      if (this.index[target] != null) {
        d = _.clone(this.index[target]);
        d.data = fs.readFileSync(d.path, 'utf8');
        r = this.parseRequireDirective(d.data);
        d.deps = this.findDependencies(r, opts);
        d.opts = this.compillerOptions;
        result.push(d);
      } else {
        console.log(("Error: " + target + " not found").red);
      }
    }
    return result;
  };

  return Compiller;

})();
