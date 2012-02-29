/*!
 * nBuild
 * Copyright(c) 2011-2012 vol4ok <admin@vol4ok.net>
 * MIT Licensed
*/
/** Module dependencies
*/
var BANNER, Builder, OptionParser, STANDARD_PLUGIN_DIR, SWITCHES, VERSION, existsSync, fs, join, main, path, _;

require('colors');

fs = require('fs');

_ = require('underscore');

path = require('path');

OptionParser = require('coffee-script/lib/coffee-script/optparse').OptionParser;

Builder = require('./nbuild');

require('coffee.nbplug');

join = path.join, existsSync = path.existsSync;

VERSION = "0.3.0";

BANNER = 'Usage: nbuild [options] command[:step]';

SWITCHES = [['-c', '--config [FILE*]', 'path to .nproj file'], ['-e', '--environment [ARG]', 'set environment'], ['-v', '--verbose', 'verbose output'], ['-V', '--version', 'show version'], ['-p', '--plugin [FILE*]', 'add plugin file or dir'], ['-h', '--help', 'display this help message']];

STANDARD_PLUGIN_DIR = "" + __dirname + "/../plugins";

/** Entry point
*/

main = function() {
  var builder, builderOptions, cfg, cmd, configFiles, file, o, optParser, plugins, _i, _j, _k, _len, _len2, _len3, _ref, _ref2, _ref3, _results;
  optParser = new OptionParser(SWITCHES, BANNER);
  o = optParser.parse(process.argv.slice(2));
  if (o.help) {
    console.log(optParser.help());
    return;
  }
  if (o.version) {
    console.log("nbuild v" + VERSION);
    return;
  }
  configFiles = [];
  if (o.config != null) {
    _ref = o.config;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      cfg = _ref[_i];
      if (existsSync(cfg)) {
        configFiles = _.union(configFiles, fs.realpathSync(cfg));
      }
    }
  }
  if (configFiles.length === 0) {
    _ref2 = fs.readdirSync(process.cwd());
    for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
      file = _ref2[_j];
      if (!(/\.nbproj$/i.test(file))) continue;
      configFiles.push(fs.realpathSync(join(process.cwd(), file)));
      break;
    }
  }
  if (configFiles.length === 0) {
    console.log("Config wasn't found, read the help for more information `nbuild -h`".yellow);
    return;
  }
  plugins = [STANDARD_PLUGIN_DIR];
  if (o.plugins) plugins = plugins.concat(o.plugins);
  builderOptions = {};
  if (o.verbose) builderOptions.verbose = o.verbose;
  if (o.environment) builderOptions.environment = o.environment;
  builderOptions.plugins = plugins;
  builderOptions.configFiles = configFiles;
  builder = new Builder(builderOptions);
  if (o.arguments.length > 0) {
    _ref3 = o.arguments;
    _results = [];
    for (_k = 0, _len3 = _ref3.length; _k < _len3; _k++) {
      cmd = _ref3[_k];
      _results.push(builder.exec(cmd));
    }
    return _results;
  } else {
    return builder.exec();
  }
};

main();
