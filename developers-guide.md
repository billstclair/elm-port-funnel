# PortFunnel-Aware Module Developer's Guide

What a user should expect from a module that plugs into the `PortFunnel` library.

## Simple JavaScript install

Copy one `.js` file into the `js/PortFunnel` directory, or wherever else they've decided to store them. If your module is named `MyModule`, that JS file should be named "`MyModule.js`. It should create NO top-level JS variables. When it loads, it must set `PortFunnel.modules[&lt;moduleName>].cmd` to a dispatch function of two args, `tag` and `args`, which returns a value to be sent back to the user, or `null` to not send anything.

`PortFunnel.sub` is the user's subscription port. It has a `send` property, a function of one argument, which you may call to send a value in to that port. That value (and the return value of the dispatch function) must be of the form:

    { module: &lt;moduleName>,
      tag: &lt;message tag>,
      args: &lt;anything your decoder can grok>
    }
    
Here's an example from [AddXY.js](example/site/js/PortFunnel/AddXY.js):

    (function() {
      var moduleName = 'AddXY';
      var sub = PortFunnel.sub;

      PortFunnel.modules[moduleName].cmd = dispatcher;

      function dispatcher(tag, args) {
        function callback() {
          sub.send({ module: moduleName,
                     tag: "sum",
                     args: { x: args.x + 1,
                             y: args.y + 1,
                             sum: args.x + args.y + 2
                           }
                   });
        }

        setTimeout(callback, 1000);

        return { module: moduleName,
                 tag: "sum",
                 args: { x: args.x, y: args.y, sum: args.x + args.y }
               }
      }
    })();

## Standard Exposed Functions

There's no way to enforce this, but users will expect your Elm module to expose the following. See the [AddXY.elm](example/AddXY.elm) example.

`PortFunnel.Echo` is a funnel that ships with the package, illustrating best practices. The JavaScript for it is in `example/site/js/PortFunnel/Echo.js`. But you can use it in `elm reactor` via its `makeSimulatedCmdPort` function.

* `Message(..)` is your message type. Fully exposed, or not. As long as there's a way for users to create and inspect the messages they need to care about, all is good.

* `Response(..)` is the second value returned by your `moduleDesc` processor function. This is how users get information from the messages received over the subscription port.

* `State` is your funnel's state type. It can be `()` if you don't need state.

* `moduleName` is your module's name, matching the `.moduleName` of the `GenericMessage` returned by `moduleDesc.encode`.

* `moduleDesc` is created with `PortFunnel.makeModuleDesc`.

* `commander` turns a `tagger` and a `response` into a `Cmd`. This is how a funnel sends commands to its own JavaScript.

* `initialState` is how the user gets the initial value of your module's `State`.

* `send` encodes a `message` and sends it over a `Cmd` port. Same as `PortFunnel.sendMessage moduleDesc`.

* `makeSimulatedCmdPort` turns an application tagger (`Value -> Cmd msg`) into a simulated `Cmd` port.

* `toString` converts a `Message` to a pretty string.

* `toJsonString` converts a message to a JSON string. Same as `PortFunnel.messageToJsonString moduleDesc`.

Usually, there will also be functions to make `Message`s, but those are tagger-specific, so hard to standardize.
