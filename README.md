# GanDengYan

A Chinese card game similar to Big Two or Tycoon implemented in Elixir.

## Description

GanDengYan is a card game where players take turns playing card patterns,
trying to be the first to play all their cards.

## Features

- TCP server implementation for networked play
- Command-line interface
- Multiple player support

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gandengyan` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gandengyan, "~> 0.1.0"}
  ]
end
```

## Running the Game

You can run the game as an escript:

```bash
# Build the escript
mix escript.build

# Run the game
./gandengyan
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gandengyan>.
