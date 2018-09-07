//////////////////////////////////////////////////////////////////////
//
// AddXY.js
// An example PortFunnel port that adds its x & y args and returns the sum as sum.
// It also illustrates asynchronous sends through the Sub port.
// Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
// Some rights reserved.
// Distributed under the MIT License
// See LICENSE
//
//////////////////////////////////////////////////////////////////////


(function() {
  var moduleName = 'AddXY';
  var sub = PortFunnel.sub;

  PortFunnel.modules[moduleName].cmd = dispatcher;

  function dispatcher(tag, args) {
    var returnTag = tag=='add' ? 'sum' : 'product';
    var operation = tag=='add' ? add : multiply;

    function add(x, y) { return x + y }
    function multiply(x, y) { return x * y }

    function callback() {
      sub.send({ module: moduleName,
                 tag: returnTag,
                 args: { x: args.x + 1,
                         y: args.y + 1,
                         result: operation(args.x + 1, args.y + 1)
                       }
               });
    }

    setTimeout(callback, 1000);

    return { module: moduleName,
             tag: returnTag,
             args: { x: args.x,
                     y: args.y,
                     result: operation(args.x, args.y) }
           }
  }
})();
