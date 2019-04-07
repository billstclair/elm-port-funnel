//////////////////////////////////////////////////////////////////////
//
// Echo.js
// An example PortFunnel port that echoes its input.
// Copyright (c) 2018-2019 Bill St. Clair <billstclair@gmail.com>
// Some rights reserved.
// Distributed under the MIT License
// See LICENSE
//
//////////////////////////////////////////////////////////////////////


(function(scope) {
  var moduleName = 'Echo';
  var sub;

  function init() {
    var PortFunnel = scope.PortFunnel;
    if (!PortFunnel || !PortFunnel.sub || !PortFunnel.modules) {
      // Loop until PortFunnel.js has initialized itself.
      setTimeout(init, 10);
      return;
    }
    
    sub = PortFunnel.sub;
    PortFunnel.modules[moduleName] = { cmd: dispatcher };

    // Let the Elm code know we've started.
    sub.send({ module: moduleName,
               tag: "startup",
               args: null
             });
  }
  init();

  function dispatcher(tag, args) {
    return { module: moduleName,
             tag: tag,
             args: args
           };
  }
})(this);
