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
    function callback() {
      sub.send('Delayed Greeting');
    }

    setTimeout(callback, 1000);

    return { module: moduleName
             , tag: tag
             , args: { x: args.x, y: args.y, sum: args.x + args.y }
           }
  }
})();
