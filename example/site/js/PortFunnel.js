//////////////////////////////////////////////////////////////////////
//
// PortFunnel.js
// JavaScript runtime code for billstclair/elm-port-funnel
// Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
// Some rights reserved.
// Distributed under the MIT License
// See LICENSE
//
//////////////////////////////////////////////////////////////////////
//
// PortFunnel is the single global variable defined by this file.
// It is an object with a `subscribe` property, a function, called as:
//
//   PortFunnel.subscribe
//     (app, {portnames: ['portFunnelCmd', 'portFunnelSub'],
//            funnels: ['Funnel1', ...]
//           });
//
// The `ports` property is optional. If included, its value should be a
// two-element array containing the name of the `Cmd` and `Sub` ports in
// `app`. They default as specified above.
//
// The `funnels` property is a list of strings, each of which should
// correspond to a JavaScript file in the same directory as this file.
// Each implements the same protocol described in `ExampleFunnel.js`.
//
// Each `funnel` JavaScript file is loaded.
// It should set `PortFunnel.funnels['funnelName']`, as illustrated in
// `ExampleFunnel.js`,so that it can be hooked in to the funnelling
//  mechanism below.
//
//////////////////////////////////////////////////////////////////////

var PortFunnel = {};

(function() {

PortFunnel.subscribe = subscribe; // called by HTML file
PortFunnel.funnels = {};          // funnels[funnelName].cmd set by funnel JS.
PortFunnel.sub = null;          // set below

function subscribe(app, args) {
  if (!args) args = {};
  var portNames = args.portNames;
  if (!portNames) {
    portNames = ['portFunnelCmd', 'portFunnelSub'];
  }

  var ports = app.ports;
  var sub = ports[portNames[1]];
  PortFunnel.sub = sub;

  var cmd = ports[portNames[0]];
  cmd.subscribe(function(command) {
    var returnValue = commandDispatch(command);
    if (returnValue) sub.send(returnValue);
  });  

  var funnels = args.funnels;
  if (funnels) {
    for (var i in funnels) {
      loadFunnel(funnels[i]);
    }
  }
}

// Load 'funnels/'+funnelName+'.js'
// Expect it to set PortFunnel.funnels[funnelName].cmd to
// a function of two args, tag and args.
function loadFunnel(funnelName) {
  PortFunnel.funnels[funnelName] = {};

  var src = 'funnels/' + funnelName + '.js';
  var script = document.createElement('script');
  script.type = 'text/javascript';
  script.src = src;

  document.head.appendChild(script);
}

// command is of the form:
//    { funnel: 'funnelName',
//      tag: 'command name for funnel',
//      args: {name: value, ...}
//    }
function commandDispatch(command) {
  if (typeof(command) == 'object') {
    var funnelName = command.funnel;
    var funnel = funnels[funnelName];
    if (funnel) {
      var cmd = funnel.cmd;
      if (cmd) {
        var tag = command.tag;
        var args = command.args;
        cmd(tag, args);
      }
    }
  }
}

})()
