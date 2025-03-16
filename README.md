# GanDengYan

A Chinese card game similar to Big Two or Tycoon implemented in Elixir.

## Description

GanDengYan is a card game where players take turns playing card patterns,
trying to be the first to play all their cards.

## Rules of Play

### Overview

GanDengYan (lit. "Follow the Leader") is a shedding-type card game where players aim to be the first to play all their cards. The game uses strategy and skill to outplay opponents with increasingly powerful card combinations.

### Card Deck

- Standard 52-card deck plus 2 jokers (54 cards total)
- Card ranking (lowest to highest): 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K, A, 2, Joker
- Note: 2 is ranked higher than Ace in this game

### Setup

1. The first player to join becomes the banker (dealer)
2. The banker receives 7 cards, all other players receive 6 cards
3. The banker plays first and cannot pass on the first turn

### Valid Card Patterns

- **Single**: Any individual card (except a single Joker)
- **Pair**: Two cards of the same rank (e.g., two Queens)
- **Triplet/Bomb**: Three cards of the same rank (e.g., three 5s)
- **Four of a Kind/Abomb**: Four cards of the same rank (e.g., four Jacks)
- **Sequence**: Three consecutive cards (e.g., 5-6-7)
- **Straight Pairs**: Two consecutive pairs (e.g., two 7s and two 8s)

### Special Joker Rules

- Jokers can be used as wildcards to complete any pattern
- A pair of Jokers is considered a bomb
- Jokers have the highest individual card value

### Turn Structure

1. Play proceeds clockwise around the table
2. Players must either play a valid card pattern that beats the previous play or pass
3. The first player in a round cannot pass
4. If a player passes, they don't play any cards and the turn moves to the next player
5. If all players pass except one, that player wins the round and starts a new one
6. A player who wins a round (everyone else passes) draws a card and starts the next round with any valid pattern

### Pattern Beating Rules

- A pattern can only beat a pattern of the same type (with exceptions below)
- Within the same pattern type, higher card values win (e.g., a pair of Kings beats a pair of Queens)
- **Bombs** (triplets) can beat any non-bomb pattern
- **Abombs** (four of a kind) can beat bombs and any other pattern
- **Special case**: A pair of Jokers is considered a powerful bomb

### Winning the Game

- The first player to play all their cards wins the game
- Players aim to strategically use their high cards and special combinations

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

To create a game:

1. Launch the game and select "create"
2. Enter your name
3. Wait for other players to join
4. When ready, start the game

To join a game:

1. Launch the game and select "join"
2. Enter the host IP (or use localhost for local games)
3. Enter your name to join the game

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gandengyan>.
