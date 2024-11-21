# IgniterTlsEnable

This is a set of steps I'm using to turn on TLS with a bunch of local X509 certificates.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `igniter_tls_enable` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:igniter_tls_enable, github: "chgeuer/igniter_tls_enable", force: true}
  ]
end
```

A local installation would look like this

```elixir
def deps do
  [
    {:igniter_tls_enable, path: "../igniter_tls_enable"}
  ]
end
```

After `mix deps.get`, you can then add TLS support:

```shell
mix phx.new hello_world --no-ecto --no-gettext --no-assets --no-live --no-html --no-dashboard --no-esbuild --no-tailwind --no-mailer
cd hello_world
# add {:igniter_tls_enable, path: "../igniter_tls_enable"} to mix.exs
mix deps.get
mix Igniter.Task.TLSEnable --hostname beast.geuer-pollmann.de
mix deps.get
iex -S mix phx.server.browser
```
