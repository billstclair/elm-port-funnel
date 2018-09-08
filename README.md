# Funneling Your Ports

[billstclair/elm-port-funnel](https://package.elm-lang.org/packages/billstclair/elm-port-funnel/latest) allows you to use a single outgoing/incoming pair of `port`s to communicate with the JavaScript for any number of `PortFunnel`-aware modules, which I'm going to call "funnels".

On the JavaScript side, you pick a directory for `PortFunnel.js` and the JavaScript files for the funnels. Some boilerplate JS in your `index.html` file loads `PortFunnel.js`, and tells it the names of the funnels. It takes care of loading them and wiring them up.

On the Elm side, you create the two ports, tell the `PortFunnel` module about them with a `Config` instance, call the action functions in the funnel modules, in response to events, and dispatch off of the `name` field in the `GenericMessage` you get from your subscription port, to `process` that message in each specific module, and handle its `result`. This is illustrated in [example/Main.elm](https://github.com/billstclair/elm-port-funnel/blob/master/example/Main.elm).

[DEVELOPERS-GUIDE.md](https://github.com/billstclair/elm-port-funnel/blob/master/DEVELOPERS-GUIDE.md) has details for people who want to write funnels. For simple examples, see the files `Echo.elm` and `AddXY.elm` in the `src/PortFunnel` directory, and the corresponding `Echo.js` and `AddXY.js` files in the `example/site/js/PortFunnel` directory.

The example is live at https://billstclair.github.io/elm-port-funnel

## Existing Funnel Modules

Currently, the `PortFunnel.Echo` and `PortFunnel.AddXY` modules, which ship with `billstclair/elm-port-funnel`, are the only funnel modules. I'll be working on upgrading my existing port packages to funnels (`billstclair/elm-websocket-client`, `billstclair/elm-localstorage`, `billstclair/elm-dev-random`).

## Credit

Thank you to Murphy Randall (@splodingsocks on Twitter and Elm Slack), whose [elm-conf 2017 talk](https://www.youtube.com/watch?v=P3pL85n9_5s) introduced me to the idea that `billstclair/elm-port-funnel` takes to its logical extreme.
