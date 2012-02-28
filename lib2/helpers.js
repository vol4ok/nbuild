/*!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
*/
/** Module dependencies
*/
var basename, cleanDir, deepExtend, dirname, existsSync, extname, fs, generateFiles, generateName, join, mkdirp, normalize, path, rand, relative, _,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

fs = require('fs');

path = require('path');

_ = require('underscore');

normalize = path.normalize, basename = path.basename, dirname = path.dirname, extname = path.extname, join = path.join, existsSync = path.existsSync, relative = path.relative;

rand = function(n) {
  return Math.floor(Math.random() * n);
};

generateName = function(alphabet, length) {
  var i, name;
  name = "";
  for (i = 0; 0 <= length ? i < length : i > length; 0 <= length ? i++ : i--) {
    name += alphabet[rand(alphabet.length)];
  }
  return name;
};

mkdirp = function(path, mode, createdDirs) {
  var parent;
  if (mode == null) mode = 0755;
  if (createdDirs == null) createdDirs = null;
  parent = dirname(path);
  if (!existsSync(parent)) mkdirp(parent, mode);
  if (!existsSync(path)) {
    fs.mkdirSync(path, mode);
    if (_.isArray(createdDirs)) return createdDirs.push(path);
  }
};

cleanDir = function(path) {
  var f, _i, _len, _ref, _results;
  _ref = fs.readdirSync(path);
  _results = [];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    f = _ref[_i];
    _results.push(fs.unlinkSync(join(path, f)));
  }
  return _results;
};

generateFiles = function(dir, count, maxSize, callback) {
  var files, i;
  files = [];
  for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
    files.push(join(dir, generateName(ALPHABET, 10)));
  }
  async.forEach(files, function(file, cb) {
    return exec("dd if=/dev/urandom of=" + file + " bs=1 count=" + (rand(maxSize)), cb);
  }, callback);
  return files;
};

deepExtend = function() {
  var args, clone, i, key, obj, src, target, val, _i, _len, _ref;
  args = [];
  if (arguments.length < 1 || typeof arguments[0] !== "object") return false;
  target = arguments[0];
  for (i = 1, _ref = arguments.length; 1 <= _ref ? i < _ref : i > _ref; 1 <= _ref ? i++ : i--) {
    args.push(arguments[i]);
  }
  if (!(args.length > 0)) return target;
  for (_i = 0, _len = args.length; _i < _len; _i++) {
    obj = args[_i];
    if (typeof obj !== "object") continue;
    for (key in obj) {
      val = obj[key];
      if (!(obj[key] !== void 0)) continue;
      src = target[key];
      if (val === target) continue;
      if (typeof val !== "object") {
        target[key] = val;
        continue;
      }
      if (typeof src !== "object") {
        clone = (_.isArray(val) ? [] : {});
        target[key] = deepExtend(clone, val);
        continue;
      }
      if (_.isArray(val)) {
        clone = (_.isArray(src) ? src : []);
      } else {
        clone = (!_.isArray(src) ? src : {});
      }
      target[key] = deepExtend(clone, val);
    }
  }
  return target;
};

__extends(exports, {
  rand: rand,
  generateName: generateName,
  mkdirp: mkdirp,
  cleanDir: cleanDir,
  generateFiles: generateFiles,
  deepExtend: deepExtend
});
