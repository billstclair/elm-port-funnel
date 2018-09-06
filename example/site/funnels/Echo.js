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
  var funnelName = 'Echo';
  PortFunnel.funnels[funnelName].cmd = dispatcher;

  function dispatcher(tag, args) {
    return { funnel: funnelName,
             tag: tag,
             args: args
           };
  }
})();
