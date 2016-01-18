
'use strict';

var global = window

var _slicedToArray = (function () { function sliceIterator(arr, i) { var _arr = []; var _n = true; var _d = false; var _e = undefined; try { for (var _i = arr[Symbol.iterator](), _s; !(_n = (_s = _i.next()).done); _n = true) { _arr.push(_s.value); if (i && _arr.length === i) break; } } catch (err) { _d = true; _e = err; } finally { try { if (!_n && _i['return']) _i['return'](); } finally { if (_d) throw _e; } } return _arr; } return function (arr, i) { if (Array.isArray(arr)) { return arr; } else if (Symbol.iterator in Object(arr)) { return sliceIterator(arr, i); } else { throw new TypeError('Invalid attempt to destructure non-iterable instance'); } }; })();

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

function _objectWithoutProperties(obj, keys) { var target = {}; for (var i in obj) { if (keys.indexOf(i) >= 0) continue; if (!Object.prototype.hasOwnProperty.call(obj, i)) continue; target[i] = obj[i]; } return target; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

var __DEV__ = false;

var invariant = function invariant(condition, format, a, b, c, d, e, f) {
  if (__DEV__) {
    if (format === undefined) {
      throw new Error('invariant requires an error message argument');
    }
  }

  if (!condition) {
    var error;
    if (format === undefined) {
      error = new Error('Minified exception occurred; use the non-minified dev environment ' + 'for the full error message and additional helpful warnings.');
    } else {
      var args = [a, b, c, d, e, f];
      var argIndex = 0;
      error = new Error(format.replace(/%s/g, function () {
        return args[argIndex++];
      }));
      error.name = 'Invariant Violation';
    }

    error.framesToPop = 1; // we don't care about invariant's own frame
    throw error;
  }
};

var MODULE_IDS = 0;
var METHOD_IDS = 1;
var PARAMS = 2;
var CALL_IDS = 3;
var MIN_TIME_BETWEEN_FLUSHES_MS = 5;

var TRACE_TAG_REACT_APPS = 1 << 17;

var SPY_MODE = false;

var MethodTypes = {};
MethodTypes.remote = 0;
MethodTypes.remoteAsync = 1;

var guard = function guard(fn) {
  try {
    fn();
  } catch (error) {}
};

var MessageQueue = (function () {
  function MessageQueue(remoteModules, localModules) {
    var _this = this;

    _classCallCheck(this, MessageQueue);

    this.RemoteModules = {};

    this._callableModules = {};
    this._queue = [[], [], [], 0];
    this._moduleTable = {};
    this._methodTable = {};
    this._callbacks = [];
    this._callbackID = 0;
    this._callID = 0;
    this._lastFlush = 0;
    this._eventLoopStartTime = new Date().getTime();

    ['invokeCallbackAndReturnFlushedQueue', 'callFunctionReturnFlushedQueue', 'flushedQueue'].forEach(function (fn) {
      return _this[fn] = _this[fn].bind(_this);
    });

    var modulesConfig = this._genModulesConfig(remoteModules);
    this._genModules(modulesConfig);
    localModules && this._genLookupTables(this._genModulesConfig(localModules), this._moduleTable, this._methodTable);

    this._debugInfo = {};
    this._remoteModuleTable = {};
    this._remoteMethodTable = {};
    this._genLookupTables(modulesConfig, this._remoteModuleTable, this._remoteMethodTable);
  }

  /**
   * Public APIs
   */

  _createClass(MessageQueue, [{
    key: 'callFunctionReturnFlushedQueue',
    value: function callFunctionReturnFlushedQueue(module, method, args) {
      var _this2 = this;

      guard(function () {
        _this2.__callFunction(module, method, args);
        _this2.__callImmediates();
      });

      return this.flushedQueue();
    }
  }, {
    key: 'invokeCallbackAndReturnFlushedQueue',
    value: function invokeCallbackAndReturnFlushedQueue(cbID, args) {
      var _this3 = this;

      guard(function () {
        _this3.__invokeCallback(cbID, args);
        _this3.__callImmediates();
      });

      return this.flushedQueue();
    }
  }, {
    key: 'flushedQueue',
    value: function flushedQueue() {
      this.__callImmediates();

      var queue = this._queue;
      this._queue = [[], [], [], this._callID];
      return queue[0].length ? queue : null;
    }
  }, {
    key: 'processModuleConfig',
    value: function processModuleConfig(config, moduleID) {
      var module = this._genModule(config, moduleID);
      this._genLookup(config, moduleID, this._remoteModuleTable, this._remoteMethodTable);
      return module;
    }
  }, {
    key: 'getEventLoopRunningTime',
    value: function getEventLoopRunningTime() {
      return new Date().getTime() - this._eventLoopStartTime;
    }

    /**
     * "Private" methods
     */

  }, {
    key: '__callImmediates',
    value: function __callImmediates() {}
  }, {
    key: '__nativeCall',
    value: function __nativeCall(module, method, params, onFail, onSucc) {
      if (onFail || onSucc) {
        // eventually delete old debug info
        this._callbackID > 1 << 5 && (this._debugInfo[this._callbackID >> 5] = null);

        this._debugInfo[this._callbackID >> 1] = [module, method];
        onFail && params.push(this._callbackID);
        this._callbacks[this._callbackID++] = onFail;
        onSucc && params.push(this._callbackID);
        this._callbacks[this._callbackID++] = onSucc;
      }

      global.nativeTraceBeginAsyncFlow && global.nativeTraceBeginAsyncFlow(TRACE_TAG_REACT_APPS, 'native', this._callID);
      this._callID++;

      this._queue[MODULE_IDS].push(module);
      this._queue[METHOD_IDS].push(method);
      this._queue[PARAMS].push(params);

      var now = new Date().getTime();
      if (global.nativeFlushQueueImmediate && now - this._lastFlush >= MIN_TIME_BETWEEN_FLUSHES_MS) {
        global.nativeFlushQueueImmediate(this._queue);
        this._queue = [[], [], [], this._callID];
        this._lastFlush = now;
      }
      if (__DEV__ && SPY_MODE && isFinite(module)) {
        console.log('JS->N : ' + this._remoteModuleTable[module] + '.' + this._remoteMethodTable[module][method] + '(' + JSON.stringify(params) + ')');
      }
    }
  }, {
    key: '__callFunction',
    value: function __callFunction(module, method, args) {
      this._lastFlush = new Date().getTime();
      this._eventLoopStartTime = this._lastFlush;
      if (isFinite(module)) {
        method = this._methodTable[module][method];
        module = this._moduleTable[module];
      }
      if (__DEV__ && SPY_MODE) {
        console.log('N->JS : ' + module + '.' + method + '(' + JSON.stringify(args) + ')');
      }
      var moduleMethods = this._callableModules[module];
      invariant(!!moduleMethods, 'Module %s is not a registered callable module.', module);
      moduleMethods[method].apply(moduleMethods, args);
    }
  }, {
    key: '__invokeCallback',
    value: function __invokeCallback(cbID, args) {
      this._lastFlush = new Date().getTime();
      this._eventLoopStartTime = this._lastFlush;
      var callback = this._callbacks[cbID];
      var debug = this._debugInfo[cbID >> 1];
      var module = debug && this._remoteModuleTable[debug[0]];
      var method = debug && this._remoteMethodTable[debug[0]][debug[1]];
      invariant(callback, 'Callback with id ' + cbID + ': ' + module + '.' + method + '() not found');
      var profileName = debug ? '<callback for ' + module + '.' + method + '>' : cbID;
      if (callback && SPY_MODE && __DEV__) {
        console.log('N->JS : ' + profileName + '(' + JSON.stringify(args) + ')');
      }

      this._callbacks[cbID & ~1] = null;
      this._callbacks[cbID | 1] = null;
      callback.apply(null, args);
    }

    /**
     * Private helper methods
     */

    /**
     * Converts the old, object-based module structure to the new
     * array-based structure. TODO (t8823865) Removed this
     * function once Android has been updated.
     */
  }, {
    key: '_genModulesConfig',
    value: function _genModulesConfig(modules /* array or object */) {
      if (Array.isArray(modules)) {
        return modules;
      } else {
        var moduleArray = [];
        var moduleNames = Object.keys(modules);
        for (var i = 0, l = moduleNames.length; i < l; i++) {
          var moduleName = moduleNames[i];
          var moduleConfig = modules[moduleName];
          var _module2 = [moduleName];
          if (moduleConfig.constants) {
            _module2.push(moduleConfig.constants);
          }
          var methodsConfig = moduleConfig.methods;
          if (methodsConfig) {
            var methods = [];
            var asyncMethods = [];
            var methodNames = Object.keys(methodsConfig);
            for (var j = 0, ll = methodNames.length; j < ll; j++) {
              var methodName = methodNames[j];
              var methodConfig = methodsConfig[methodName];
              methods[methodConfig.methodID] = methodName;
              if (methodConfig.type === MethodTypes.remoteAsync) {
                asyncMethods.push(methodConfig.methodID);
              }
            }
            if (methods.length) {
              _module2.push(methods);
              if (asyncMethods.length) {
                _module2.push(asyncMethods);
              }
            }
          }
          moduleArray[moduleConfig.moduleID] = _module2;
        }
        return moduleArray;
      }
    }
  }, {
    key: '_genLookupTables',
    value: function _genLookupTables(modulesConfig, moduleTable, methodTable) {
      var _this4 = this;

      modulesConfig.forEach(function (config, moduleID) {
        _this4._genLookup(config, moduleID, moduleTable, methodTable);
      });
    }
  }, {
    key: '_genLookup',
    value: function _genLookup(config, moduleID, moduleTable, methodTable) {
      if (!config) {
        return;
      }

      var moduleName = undefined,
          methods = undefined;
      if (moduleHasConstants(config)) {
        var _config = _slicedToArray(config, 3);

        moduleName = _config[0];
        methods = _config[2];
      } else {
        var _config2 = _slicedToArray(config, 2);

        moduleName = _config2[0];
        methods = _config2[1];
      }

      moduleTable[moduleID] = moduleName;
      methodTable[moduleID] = Object.assign({}, methods);
    }
  }, {
    key: '_genModules',
    value: function _genModules(remoteModules) {
      var _this5 = this;

      remoteModules.forEach(function (config, moduleID) {
        _this5._genModule(config, moduleID);
      });
    }
  }, {
    key: '_genModule',
    value: function _genModule(config, moduleID) {
      var _this6 = this;

      if (!config) {
        return;
      }

      var moduleName = undefined,
          constants = undefined,
          methods = undefined,
          asyncMethods = undefined;
      if (moduleHasConstants(config)) {
        var _config3 = _slicedToArray(config, 4);

        moduleName = _config3[0];
        constants = _config3[1];
        methods = _config3[2];
        asyncMethods = _config3[3];
      } else {
        var _config4 = _slicedToArray(config, 3);

        moduleName = _config4[0];
        methods = _config4[1];
        asyncMethods = _config4[2];
      }

      var module = {};
      methods && methods.forEach(function (methodName, methodID) {
        var methodType = asyncMethods && arrayContains(asyncMethods, methodID) ? MethodTypes.remoteAsync : MethodTypes.remote;
        module[methodName] = _this6._genMethod(moduleID, methodID, methodType);
      });
      Object.assign(module, constants);

      if (!constants && !methods && !asyncMethods) {
        module.moduleID = moduleID;
      }

      this.RemoteModules[moduleName] = module;
      return module;
    }
  }, {
    key: '_genMethod',
    value: function _genMethod(module, method, type) {
      var fn = null;
      var self = this;
      if (type === MethodTypes.remoteAsync) {
        fn = function () {
          for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
            args[_key] = arguments[_key];
          }

          return new Promise(function (resolve, reject) {
            self.__nativeCall(module, method, args, resolve, function (errorData) {
              var error = createErrorFromErrorData(errorData);
              reject(error);
            });
          });
        };
      } else {
        fn = function () {
          for (var _len2 = arguments.length, args = Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
            args[_key2] = arguments[_key2];
          }

          var lastArg = args.length > 0 ? args[args.length - 1] : null;
          var secondLastArg = args.length > 1 ? args[args.length - 2] : null;
          var hasSuccCB = typeof lastArg === 'function';
          var hasErrorCB = typeof secondLastArg === 'function';
          hasErrorCB && invariant(hasSuccCB, 'Cannot have a non-function arg after a function arg.');
          var numCBs = hasSuccCB + hasErrorCB;
          var onSucc = hasSuccCB ? lastArg : null;
          var onFail = hasErrorCB ? secondLastArg : null;
          args = args.slice(0, args.length - numCBs);
          return self.__nativeCall(module, method, args, onFail, onSucc);
        };
      }
      fn.type = type;
      return fn;
    }
  }, {
    key: 'registerCallableModule',
    value: function registerCallableModule(name, methods) {
      this._callableModules[name] = methods;
    }
  }]);

  return MessageQueue;
})();

function moduleHasConstants(moduleArray) {
  return !Array.isArray(moduleArray[1]);
}

function arrayContains(array, value) {
  return array.indexOf(value) !== -1;
}

function createErrorFromErrorData(errorData) {
  var message = errorData.message;

  var extraErrorInfo = _objectWithoutProperties(errorData, ['message']);

  var error = new Error(message);
  error.framesToPop = 1;
  return Object.assign(error, extraErrorInfo);
}

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule BatchedBridge
 */

var BatchedBridge = new MessageQueue(__fbBatchedBridgeConfig.remoteModuleConfig, __fbBatchedBridgeConfig.localModulesConfig);

// Wire up the batched bridge on the global object so that we can call into it.
// Ideally, this would be the inverse relationship. I.e. the native environment
// provides this global directly with its script embedded. Then this module
// would export it. A possible fix would be to trim the dependencies in
// MessageQueue to its minimal features and embed that in the native runtime.

Object.defineProperty(global, '__fbBatchedBridge', { value: BatchedBridge });

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule NativeModules
 * 
 */

var RemoteModules = BatchedBridge.RemoteModules;

function normalizePrefix(moduleName) {
  return moduleName.replace(/^(RCT|RK)/, '');
}

/**
 * Dirty hack to support old (RK) and new (RCT) native module name conventions.
 */
Object.keys(RemoteModules).forEach(function (moduleName) {
  var strippedName = normalizePrefix(moduleName);
  if (RemoteModules['RCT' + strippedName] && RemoteModules['RK' + strippedName]) {
    throw new Error('Module cannot be registered as both RCT and RK: ' + moduleName);
  }
  if (strippedName !== moduleName) {
    RemoteModules[strippedName] = RemoteModules[moduleName];
    delete RemoteModules[moduleName];
  }
});

/**
 * Define lazy getters for each module.
 * These will return the module if already loaded, or load it if not.
 */
var NativeModules = {};
Object.keys(RemoteModules).forEach(function (moduleName) {
  Object.defineProperty(NativeModules, moduleName, {
    enumerable: true,
    get: function get() {
      var module = RemoteModules[moduleName];
      if (module && typeof module.moduleID === 'number' && global.nativeRequireModuleConfig) {
        var json = global.nativeRequireModuleConfig(moduleName);
        var config = json && JSON.parse(json);
        module = config && BatchedBridge.processModuleConfig(config, module.moduleID);
        RemoteModules[moduleName] = module;
      }
      return module;
    }
  });
});

Object.defineProperty(global, 'NativeModules', { value: NativeModules });