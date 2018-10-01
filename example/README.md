# PortFunnel Example and Ports

## Running the Examples

This directory contains three top-level Elm program files:

1. `Main.elm` is an example, running at [billstclair.github.io/elm-port-funnel](https://billstclair.github.io/elm-port-funnel/). It shows port detection and simulators for using two modules (`PortFunnel.Echo` and `PortFunnel.AddXY`) through one port pair.

   It contains a short "boilerplate" section at the top, referencing functions in the `PortFunnels` module.

2. `PortFunnels.elm` is a file for you to copy into your application and modify so that it uses all the port funnel modules you need. It should be pretty obvious how to do that. It also contains the `port` definitions for the two ports used to communicate with the JavaScript code.

You may run the examples in `elm reactor`, using simulated ports or compile them into the `site` directory, to use the real ports. To run in reactor:

    $ git clone https://github.com/billstclair/elm-port-funnel
    $ cd elm-port-funnel/example
    $ elm reactor
    
Then aim your web browser at http://localhost:8000/Main.elm, http://localhost:8000/boilerplate.elm, or http://localhost:8000/simple.elm (this one won't do anything in reactor, since it doesn't support simulation).

To build the main example and run it with ports:

    $ cd .../elm-port-funnel/example
    $ bin/build   # elm make Main.elm --output site/elm.js
    $ elm reactor
    
Then aim your web browser at http://localhost:8000/site/index.html

Or upload the `site` directory to a web server, and aim a browser at the upload directory.

## PortFunnel Port Setup

This directory contains an example of using the `PortFunnel` module with real ports. A near-image of your site directory is in the `site` sub-directory of this example directory.

The [site](site/) directory is laid out as follows (ignoring development files that you don't need to deliver with your application):

    index.html
    elm.js
    js/
      PortFunnel.js
      PortFunnel/
        AddXY.js
        Echo.js

`index.html` is the top-level file to which you point a web browser. Its `<head>` loads `elm.js`, created for this example by `bin/build`, which does:

    elm make Main.elm --output site/elm.js
    
It also loads `js/PortFunnel.js`, which contains the top-level initialization and dispatch code through which every request from Elm is funneled (the `<script>` close tags below are misspelled as `<!/script>` to avoid tickling an Elm markup bug):

      <head>
        <title>PortFunnel Example</title>
        <!-- Compile your Elm application into index.js. E.g.:
          -- elm make src/Main.elm --output site/elm.js
          -->
        <script type='text/javascript' src='elm.js'><!/script>
        <script type='text/javascript' src='js/PortFunnel.js'><!/script>
      </head>

`index.html` contains the following JavaScript to initialize Elm in a `<div>` and load the `PortFunnel` funnels:

    // Initialize the name of your main module here
    // Change "Main" to your application's module name.
    var mainModule = 'Main';

    var app = Elm[mainModule].init({
      node: document.getElementById('elm'),
    });

    // These are the defaults, so you don't need to pass them.
    // If you need to use something different, they can be passed
    // as the 'portNames' and 'moduleDirectory' properties of
    // the second parameter to PortFunnel.subscribe() below.
    //var portNames = ['cmdPort', 'subPort'];
    //var moduleDirectory = 'js/PortFunnel';

    // PortFunnel.subscribe will load js/PortFunnel/<module>.js,
    // for each module in this list.
    // Put `Echo` last, so that its `Startup` message will let you know
    // that all the JavaScript has been loaded.
    var modules = ['AddXY', 'Echo'];

    PortFunnel.subscribe(app, {modules: modules});

This code assumes your top-level application module is named `Main`. If you named it something else, change the `mainModule` setting to whatever that is.

It also assumes that the `<div>` you want to replace with Elm code has an `id` of `elm` (as appears just a little earlier in `index.html`. Again, if you like to use a different `id`, change that.

If you need to pass a flag to your top-level `init` function, add it to the `init` call.

`modules` is an array of strings. Each corresponds to the `moduleName` variable in the Elm code for the funnel, and to the name of the `.js` file that implements the JavaScript side (in the `site/js/PortFunnel` directory).

You may want to include the `Echo` module, even though you have no need for it, because after its JavaScript loads, it sends an `Echo.Startup` message, which makes `Echo.isLoaded` return `True`, so that you can tell if there is a real backend and that it loaded successfully. The example application uses this to initialize the state of its "Use Simulator" checkbox.

The `PortFunnel.subscribe(...)` call loads the `modules` and hooks them up to `app.pots`. If you use a different module for your ports than your top-level module, you'll need to change that.

## Adding a Funnel

The reason I created the `billstclair/elm-port-funnel` package is that adding a new funnel to an existing setup becomes very easy.

On the JavaScript side, you drop the new funnel's JavaScript file into the `site/js/PortFunnel` directory, and add its name to the `modules` array in `site/index.html`.

On the Elm side, you import the new module, add its initial state to your funnel state, create a new `StateAccessors` instance to access the new module's state from your funnel state, make a new simulated port, add the new funnel type to `Funnel`, and `funnels`, send the relevant funnel messages in response to application `Msg`s, and write a handler for the incoming messages from the new funnel. The last two steps are the hardest, and you'd have to do those no matter which port technology you use.
