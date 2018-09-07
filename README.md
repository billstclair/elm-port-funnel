# Funneling Your Ports

[billstclair/elm-port-funnel](https://package.elm-lang.org/packages/billstclair/elm-port-funnel/latest) allows you to use a single outgoing/incoming pair of `port`s to communicate with the JavaScript for any number of `PortFunnel`-aware modules.

On the JavaScript side, you pick a directory for `PortFunnel.js` and the JavaScript files for all the other `PortFunnel`-aware modules. Some boilerplate JS in your `index.html` file loads `PortFunnel.js`, and tells it the names of the other JavaScript files. It takes care of loading them and wiring them up.

On the Elm side, you create the two ports, tell the `PortFunnel` module about them with a `Config` instance, call the action functions from the `PortFunnel`-aware modules in response to events, and dispatch off of the `name` field in the `GenericMessage` you get from your subscription port, to `process` that message in each specific module, and handle its `result`.

[developers-guide.md](https://github.com/billstclair/elm-port-funnel/blob/master/developers-guide.md) has details for people who want to write `PortFunnel`-aware modules.

The example is live at https://billstclair.github.io/elm-port-funnel

## Credit

Thank you to Murphy Randall (@splodingsocks on Twitter and Elm Slack), whose [elm-conf 2017 talk](https://www.youtube.com/watch?v=P3pL85n9_5s) introduced me to the idea that `billstclair/elm-port-funnel` takes to its logical extreme.
