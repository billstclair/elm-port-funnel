# Funneling Your Ports

[billstclair/elm-port-funnel](https://package.elm-lang.org/packages/billstclair/elm-port-funnel/latest) allows you to use a single outgoing/incoming pair of `port`s to communicate with the JavaScript for any number of `PortFunnel`-aware modules, which I'm going to call "funnels".

On the JavaScript side, you pick a directory for `PortFunnel.js` and the JavaScript files for the funnels. Some boilerplate JS in your `index.html` file loads `PortFunnel.js`, and tells it the names of the funnels. It takes care of loading them and wiring them up.

On the Elm side, you create the two ports, tell the `PortFunnel` module about them with a `ModuleDesc` instance, call the action functions in the funnel modules, in response to events, and dispatch off of the `name` field in the `GenericMessage` you get from your subscription port, to `process` that message in each specific module, and handle its `Result`. This is illustrated by three top-level applications in the [example directory](https://github.com/billstclair/elm-port-funnel/blob/master/example).

[DEVELOPERS-GUIDE.md](https://github.com/billstclair/elm-port-funnel/blob/master/DEVELOPERS-GUIDE.md) has details for people who want to write funnels. For simple examples, see the files `Echo.elm` and `AddXY.elm` in the `src/PortFunnel` directory, and the corresponding `Echo.js` and `AddXY.js` files in the `example/site/js/PortFunnel` directory.

The README in the [example directory](https://github.com/billstclair/elm-port-funnel/tree/master/example) tells you how to configure the JavaScript for your own funnels. The main example is live at [billstclair.github.io/elm-port-funnel](https://billstclair.github.io/elm-port-funnel/).

## Existing PortFunnel Modules

`PortFunnel.Echo` and `PortFunnel.AddXY`, which ship with `billstclair/elm-port-funnel`, are the simple, canonical example modules. Below is a list of other funnel modules. If you write one, please add it to this list by submitting a pull request on this README file.

* [billstclair/elm-dev-random](https://package.elm-lang.org/packages/billstclair/elm-dev-random/latest)

  An interface to `window.crypto.getRandomValues()` for generating cryptographically secure random numbers.

* [billstclair/elm-localstorage](https://package.elm-lang.org/packages/billstclair/elm-localstorage/latest)

  An interface to the `localStorage` mechanism, for persistent storage.

* [billstclair/elm-websocket-client](https://package.elm-lang.org/packages/billstclair/elm-websocket-client/latest)

  A port-based replacement for the Elm 0.18 `elm-lang/websocket` package, which has not yet been upgraded to Elm 0.19.

* [billstclair/elm-geolocation](https://package.elm-lang.org/packages/billstclair/elm-geolocation/latest)

  A port-based replacement for the Elm 0.18 `elm-lang/geolocation` package, which was not upgraded when Elm 0.19 shipped, and may never be.

## Credit

Thank you to Murphy Randall (@splodingsocks on Twitter and Elm Slack), whose [elm-conf 2017 talk](https://www.youtube.com/watch?v=P3pL85n9_5s) introduced me to the idea that `billstclair/elm-port-funnel` takes to its logical extreme.
