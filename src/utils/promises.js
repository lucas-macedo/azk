var BB = require('bluebird');
var _  = require('lodash');

BB.onPossiblyUnhandledRejection((error) => {
  var log = require('azk/utils/log').log;
  error = error.stack ? error.stack : error;
  log.warn('[promise]', error);
  if (process.env.BLUEBIRD_DEBUG) {
    console.error(error);
  }
});

export function async(obj, func, ...args) {
  if (typeof obj == "function") {
    [func, obj] = [obj, null];
  }

  if (typeof obj == "object") {
    func = func.bind(obj);
  }

  BB.coroutine.addYieldHandler(function(yieldedValue) {
    if (typeof yieldedValue !== 'function') {
      return BB.resolve(yieldedValue);
    }
  });

  return BB.coroutine(func).apply(func, [...args]);
}

export function defer(func) {
  return new BB.Promise((resolve, reject) => {
    setImmediate(() => {
      var result;

      try {
        resolve = _.extend(resolve, { resolve: resolve, reject: reject });
        result  = func(resolve, reject);
      } catch (e) {
        return reject(e);
      }

      if (isPromise(result)) {
        result.then(resolve, reject);
      } else if (typeof(result) != "undefined") {
        resolve(result);
      }
    });
  });
}

export function asyncUnsubscribe(obj, subscription, ...args) {
  return async(obj, ...args)
  .then(function (result) {
    subscription.unsubscribe();
    return result;
  })
  .catch(function (err) {
    subscription.unsubscribe();
    throw err;
  });
}

export function promisifyClass(Klass) {
  if (_.isString(Klass)) {
    Klass = require(Klass);
  }

  var NewClass = function(...args) {
    Klass.call(this, ...args);
  };

  NewClass.prototype = Object.create(Klass.prototype);
  NewClass.prototype.constructor = Klass;

  _.each(_.methods(Klass.prototype), (method) => {
    var original = Klass.prototype[method];
    NewClass.prototype[method] = function(...args) {
      return BB.promisify(original.bind(this))(...args);
    };
  });

  return NewClass;
}

export function promisifyModule(mod) {
  var newMod = _.clone(mod);

  _.each(_.methods(mod), (method) => {
    var original = mod[method];
    newMod[method] = function(...args) {
      return BB.promisify(original.bind(this))(...args);
    };
  });

  return newMod;
}

export function when(previous, next) {
  return BB.cast(previous).then((result) => {
    return _.isFunction(next) ? next(result) : next;
  });
}

export function promisify(...args) {
  return BB.promisify(...args);
}

export function promisifyAll(...args) {
  return BB.promisifyAll(...args);
}

export function nfcall(method, ...args) {
  return BB.promisify(method)(...args);
}

export function ninvoke(obj, method, ...args) {
  return BB.promisify(obj[method].bind(obj))(...args);
}

export function nbind(obj, context) {
  return BB.promisify(obj, { context });
}

export function thenAll(...args) {
  return BB.all(...args);
}

export function all(...args) {
  return BB.all(...args);
}

export function delay(...args) {
  return BB.delay(...args);
}

export function isPromise(obj) {
  if (typeof obj === 'object') {
    return obj.hasOwnProperty('_promise0'); // bluebird promise
  }
  return false;
}

export function promiseResolve(...args) {
  return BB.resolve(...args);
}

export function promiseReject(...args) {
  return BB.reject(...args);
}

export function originalDefer(...args) {
  return BB.defer(...args);
}

export function mapPromises(...args) {
  return BB.map(...args);
}

export var TimeoutError = BB.TimeoutError;
