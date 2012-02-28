/*!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
*/
/** Module dependencies
*/
var Builder, CSON, CSON_REGEX, JSON_CMD_REGEX, VARIABLE_REGEX, YAML, YAML_REGEX, basename, coffee, deepExtend, dirname, existsSync, extname, fs, join, normalize, path, relative, _;

require("colors");

fs = require('fs');

_ = require('underscore');

path = require('path');

CSON = require('cson');

YAML = require('js-yaml');

deepExtend = require('./helpers').deepExtend;

coffee = require('coffee-script');

normalize = path.normalize, basename = path.basename, dirname = path.dirname, extname = path.extname, join = path.join, existsSync = path.existsSync, relative = path.relative;

YAML_REGEX = /^\s*#YAML/i;

CSON_REGEX = /^\s*#CSON/i;

VARIABLE_REGEX = /\$\(([\S]+?)\)/g;

JSON_CMD_REGEX = /^\$json\(([\S]+?)\)$/i;

/*
TODO
  rename some variables
  
  поддержка внутренних переменных внутри скоупа и апи для них
  базовый при для работы с файловой системой
  @json() команда на парсинга json
  @js() команда на выполнения js скрипта
  @plugin(path) команда подключания кастом плагина
  поддержка зависимостей (ключ @depend)
  @include() подгрузка сторонних конфигов
  
  парсинг cson
*/

/** 
* @class Builder сlass 
* @public
* @api
*/

Builder = (function() {
  var RESERVED_COMMANDS, STATE_FILE;

  RESERVED_COMMANDS = ["$env", "$type"];

  STATE_FILE = "_state.json";

  /**
  * @constructor
  * @public
  * @api
  * @param options.verbose     {Boolean}
  * @param options.environment {String}
  * @param options.configFiles {Array} array of path of config files
  * @param options.plugins     {Array} list of plugin or plugin's dirs
  * @description
      1) initialize fields
      2) parse each config file
      3) set global defines
      4) set global defaults
      5) set environment
      6) set work directory to main config dir
      7) oad plugins
      8) load statel
  */

  function Builder(options) {
    var config, configFile, data, hasLoad, name, parse, _i, _len, _ref, _ref2, _ref3, _ref4;
    if (options.configFiles.length === 0) throw 'Error! No config!';
    /** 
    * @field verbose {Boolean}
    * @public
    */
    this.verbose = options.verbose || false;
    /** 
    * @field plugins {Boolean}
    * @private
    */
    this.plugins = [];
    /** 
    * @field config {Object}
    * @private
    */
    this.config = {};
    /** 
    * @field defaults {Object}
    * @private
    */
    this.commandQue = [];
    /** 
    * @field lock {Boolean}
    * @private
    */
    this._lock = false;
    /** 
    * @field defaults {Object}
    * @public
    */
    this.defaults = {};
    /** 
    * @field defines {Object}
    * @public
    */
    this.defines = null;
    /** 
    * @field defaultsStack {Array}
    * @private
    */
    this.defaultsStack = [];
    /** 
    * @field definesStack {Array}
    * @private
    */
    this.definesStack = [];
    /** 
    * @field environment {String}
    * @public
    */
    this.environment = "";
    /** 
    * @field types {Object}
    * @private
    */
    this.types = {
      "batch": _.bind(this._batch, this),
      "define": _.bind(this._define, this),
      "default": _.bind(this._default, this),
      "rollback": _.bind(this._rollback, this),
      "call": _.bind(this._call, this),
      "plugin": _.bind(this._plugin, this)
    };
    hasLoad = false;
    _ref = options.configFiles;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      configFile = _ref[_i];
      if (!((configFile != null) && _.isString(configFile) && existsSync(configFile))) {
        continue;
      }
      data = fs.readFileSync(configFile, 'utf-8');
      parse = {};
      try {
        if (YAML_REGEX.test(data)) {
          parse = YAML.load(data);
        } else if (CSON_REGEX.test(data)) {
          parse = CSON.parse(data);
        } else {
          parse = JSON.parse(data);
        }
        hasLoad = true;
      } catch (err) {
        throw "JSON parse failed at " + configFile;
      }
      this.config = deepExtend(this.config, parse);
      if (this.defines == null) {
        this.defines = {
          PROJECT_NAME: basename(options.configFiles[0], extname(options.configFiles[0])),
          PROJECT_DIR: dirname(options.configFiles[0]),
          CURRENT_DIR: process.cwd()
        };
      }
    }
    if (!hasLoad) throw 'Error! No valid config!';
    this.environment = options.environment || this.config["$env"];
    _ref2 = this.config;
    for (name in _ref2) {
      config = _ref2[name];
      if (config['$type'] && config['$type'] === 'define') {
        this._define(name, config);
      }
    }
    _ref3 = this.config;
    for (name in _ref3) {
      config = _ref3[name];
      if (config['$type'] && config['$type'] === 'default') {
        this._default(name, config);
      }
    }
    _ref4 = this.config;
    for (name in _ref4) {
      config = _ref4[name];
      if (config['$type'] && config['$type'] === 'plugin') {
        this._plugin(name, config);
      }
    }
    this._scanPlugins(options.plugins);
    this._loadState();
  }

  /**
  * Locks class while async operation in process
  * @public
  */

  Builder.prototype.lock = function() {
    return this._lock = true;
  };

  /**
  * Unlock class, continue command execution
  * @public
  */

  Builder.prototype.unlock = function() {
    var _results;
    this._lock = false;
    _results = [];
    while (!this._lock && this.commandQue.length > 0) {
      _results.push(this.commandQue.shift()());
    }
    return _results;
  };

  /**
  * Set state
  * @public
  * @param name  {String}
  * @param value {Any}
  */

  Builder.prototype.setState = function(name, value) {
    if (typeof this.state[name] === 'object') {
      this.state[name] = _.extend(this.state[name], value);
    } else {
      this.state[name] = value;
    }
    return this._saveState();
  };

  /**
  * Load state from file
  * @private
  */

  Builder.prototype._loadState = function() {
    var data;
    path = join(this.defines.PROJECT_DIR, STATE_FILE);
    if (existsSync(path)) {
      try {
        data = fs.readFileSync(path, 'utf-8');
        return this.state = JSON.parse(data);
      } catch (err) {
        return console.log("Warning: invalid state file " + STATE_FILE + "!");
      }
    } else {
      return this.state = {};
    }
  };

  /**
  * Save state to file
  * @private
  */

  Builder.prototype._saveState = function() {
    var data;
    data = JSON.stringify(this.state);
    return fs.writeFileSync(join(this.defines.PROJECT_DIR, STATE_FILE), data, 'utf-8');
  };

  /**
  * Execute command string; For externals calls
  *
  * @public
  * @api
  * @param cmdstr {String}
  */

  Builder.prototype.exec = function(cmdstr) {
    process.chdir(this.defines.PROJECT_DIR);
    this._exec(cmdstr);
    return process.chdir(this.defines.CURRENT_DIR);
  };

  /**
  * Execute command string; For internals calls
  *
  * @private
  * @param cmdstr {String}
  */

  Builder.prototype._exec = function(cmdstr) {
    var cmdpath;
    cmdpath = cmdstr.split(':');
    return this.execConfig(cmdpath[cmdpath.length - 1], this._findCommandConfig(cmdpath));
  };

  /**
  * Execute config object
  *
  * @public
  * @param name    {String} config name
  * @param options {Object} config object
  */

  Builder.prototype.execConfig = function(name, config) {
    var type,
      _this = this;
    if (this._lock) {
      this.commandQue.push(function() {
        return _this.execConfig(name, config);
      });
      return;
    }
    type = config['$type'];
    if (type == null) type = 'batch';
    if (this.types[type] == null) return;
    if (type !== 'batch' && type !== 'default' && type !== 'define') {
      config = this._expandConfig(config);
    }
    return this.types[type](name, config);
  };

  /**
  * Find command config
  *
  * @private
  * @param cmdpath {String}
  */

  Builder.prototype._findCommandConfig = function(cmdpath) {
    var cmd, current, _i, _len;
    current = this.config;
    for (_i = 0, _len = cmdpath.length; _i < _len; _i++) {
      cmd = cmdpath[_i];
      if (_.indexOf(RESERVED_COMMANDS, cmd) !== -1) {
        throw "Error! Reserved command `" + cmd + "`!";
      }
      if (current[cmd] == null) throw "Error! Unknown command `" + cmd + "`!";
      current = current[cmd];
    }
    return _.clone(current);
  };

  /**
  * Scan and attach plugins
  *
  * @private
  * @description
    Plugin format:
      - plugin must export initialize(builder) function
      - plugin must have extension .plugin.coffee or .plugin.js
  */

  Builder.prototype._scanPlugins = function(plugins) {
    var file, fullpath, path, _i, _len, _results;
    if (!_.isArray(plugins)) return;
    _results = [];
    for (_i = 0, _len = plugins.length; _i < _len; _i++) {
      path = plugins[_i];
      console.log('plugin'.cyan, path);
      if (/^(\.{0,2}\/)/.test(path)) {
        console.log('parse match'.green);
        process.chdir(this.defines.PROJECT_DIR);
        path = fs.realpathSync(path);
        process.chdir(this.defines.CURRENT_DIR);
        if (fs.statSync(path).isDirectory()) {
          _results.push((function() {
            var _j, _len2, _ref, _results2;
            _ref = fs.readdirSync(path);
            _results2 = [];
            for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
              file = _ref[_j];
              if (/.*\.nbplug\.(coffee|js)$/i.test(file)) {
                fullpath = join(path, file);
                try {
                  require(fullpath).initialize(this);
                  _results2.push(this.plugins.push(fullpath));
                } catch (err) {
                  _results2.push(console.warn(("Warning: load plugin `" + fullpath + "` failed!").yellow));
                }
              } else {
                _results2.push(void 0);
              }
            }
            return _results2;
          }).call(this));
        } else {
          try {
            require(path).initialize(this);
            _results.push(this.plugins.push(path));
          } catch (err) {
            _results.push(console.warn(("Warning: load plugin `" + path + "` failed!").yellow));
          }
        }
      } else {
        console.log('right code! yes!'.red);
        try {
          require(path).initialize(this);
          _results.push(this.plugins.push(path));
        } catch (err) {
          _results.push(console.warn(("Warning: load plugin `" + path + "` failed!").yellow));
        }
      }
    }
    return _results;
  };

  /**
  * Scan and attach plugins
  *
  * @public
  * @api
  * @param name {String}   type name
  * @param func {Function} handler function
  * @param obj  {Object}   this object for function, if function is class method
  */

  Builder.prototype.registerType = function(name, func, obj) {
    if (obj == null) obj = null;
    if (obj != null) {
      return this.types[name] = _.bind(func, obj);
    } else {
      return this.types[name] = func;
    }
  };

  /**
  * Batch command — execute multiple steps
  *
  * @private
  * @param name    {String} 
  * @param options {Object}
  */

  Builder.prototype._batch = function(name, options) {
    var key, val;
    this.definesStack.push(_.clone(this.defines));
    this.defaultsStack.push(_.clone(this.defaults));
    for (key in options) {
      val = options[key];
      if (typeof val === 'object') this.execConfig(key, val);
    }
    delete this.defines;
    this.defines = this.definesStack.pop();
    delete this.defaults;
    return this.defaults = this.defaultsStack.pop();
  };

  /**
  * Parse define node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}
  */

  Builder.prototype._define = function(name, config) {
    var key, val, _results;
    if (config["$env"] && config["$env"] !== this.environment) return;
    _results = [];
    for (key in config) {
      val = config[key];
      if (key[0] === '$') continue;
      _results.push(this.defines[key] = this._parseVars(val));
    }
    return _results;
  };

  /**
  * Parse default node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}
  */

  Builder.prototype._default = function(name, config) {
    var key, val, _results;
    if (config["$env"] && config["$env"] !== this.environment) return;
    _results = [];
    for (key in config) {
      val = config[key];
      if (key[0] === '$') continue;
      _results.push(this.defaults[key] = this._parseVars(val));
    }
    return _results;
  };

  /**
  * Rollback step
  *
  * @private
  * @param name    {String} 
  * @param options {Object}
  */

  Builder.prototype._rollback = function(name, options) {
    var entry, rollback, _i, _len;
    rollback = this.state[options['step-name']].rollback;
    if (rollback == null) {
      console.warn(("Warning: rollback for `" + name + "` didn't found.").yellow);
      return;
    }
    for (_i = 0, _len = rollback.length; _i < _len; _i++) {
      entry = rollback[_i];
      if (entry.command === 'rm') {
        if (existsSync(entry.path)) fs.unlinkSync(entry.path);
        if (this.verbose) console.log(("rm " + entry.path).grey);
      } else if (entry.command === 'rmdir') {
        try {
          if (existsSync(entry.path)) fs.rmdirSync(entry.path);
          if (this.verbose) console.log("rmdir " + entry.path);
        } catch (err) {
          console.warn(("Warning: can't delete dir " + entry.path).yellow);
        }
      }
    }
    delete this.state[options['step-name']];
    return this._saveState();
  };

  /**
  * call node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}
  */

  Builder.prototype._call = function(name, config) {
    var cmd, _i, _len, _ref, _results;
    if (_.isArray(config.command)) {
      _ref = config.command;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        cmd = _ref[_i];
        _results.push(this._exec(cmd));
      }
      return _results;
    } else {
      return this._exec(config.command);
    }
  };

  /**
  * load plugin node
  *
  * @private
  * @param name    {String} 
  * @param config  {Object}
  */

  Builder.prototype._plugin = function(name, config) {
    if (config.plugin != null) this._scanPlugins([config.plugin]);
    if (config.plugins != null) return this._scanPlugins(config.plugins);
  };

  /**
  * Parse vars of each config entry
  *
  * @private
  * @param config  {Object}
  */

  Builder.prototype._expandConfig = function(config) {
    var key, result, val;
    result = _.clone(this.defaults);
    for (key in config) {
      val = config[key];
      if (key[0] === '$') continue;
      result[key] = this._parseVars(val);
    }
    return result;
  };

  /**
  * Parse variables
  * @private
  * @param val {Any} value for parse
  */

  Builder.prototype._parseVars = function(val) {
    var replacer,
      _this = this;
    replacer = function(match, name, pos, str) {
      var i;
      i = 0;
      while (pos > 0 && str[pos - 1] === '\\') {
        pos--;
        i++;
      }
      if (i % 2 === 1) return match;
      if (_.isString(_this.defines[name])) {
        return _this.defines[name];
      } else {
        return JSON.stringify(_this.defines[name]);
      }
    };
    if (_.isString(val)) {
      if (JSON_CMD_REGEX.test(val)) {
        return JSON.parse(val.replace(JSON_CMD_REGEX, replacer));
      }
      return val.replace(VARIABLE_REGEX, replacer);
    } else {
      return JSON.parse(JSON.stringify(val).replace(VARIABLE_REGEX, replacer));
    }
  };

  return Builder;

})();

module.exports = Builder;
