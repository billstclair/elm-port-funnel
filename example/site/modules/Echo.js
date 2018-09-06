//////////////////////////////////////////////////////////////////////
//
// Echo.js
// An example PortFunnel port that echoes its input.
// Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
// Some rights reserved.
// Distributed under the MIT License
// See LICENSE
//
//////////////////////////////////////////////////////////////////////


(function() {
  var moduleName = 'Echo';
  PortFunnel.modules[moduleName].cmd = dispatcher;

  function dispatcher(tag, args) {
    return { module: moduleName,
             tag: tag,
             args: args
           };
  }
})();
