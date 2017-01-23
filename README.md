# elixir-tplink-hs100

Elixir client for TP-Link HS100 and HS110 plug devices.

This library is a port of https://github.com/plasticrake/hs100-api by plasticrake.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `hs100` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:hs100, "~> 0.1.0"}]
    end
    ```

  2. Ensure `hs100` is started before your application:

    ```elixir
    def application do
      [applications: [:hs100]]
    end
    ```

