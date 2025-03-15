defmodule GanDengYan.Game.Deck do
  @moduledoc """
  Functions for creating and managing a deck of cards.
  """

  alias GanDengYan.Game.Card

  @type t :: [Card.t()]

  @doc """
  Creates a standard deck of 52 cards plus 2 jokers.

  ## Examples

      iex> deck = GanDengYan.Game.Deck.new()
      iex> length(deck)
      54
  """
  @spec new() :: t()
  def new() do
    # Standard 52-card deck
    standard_deck =
      for suit <- [:hearts, :clubs, :diamonds, :spades],
          face <- [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace],
          do: %Card{suit: suit, face: face}

    # Add jokers
    jokers = [
      %Card{suit: nil, face: :joker},
      %Card{suit: nil, face: :joker}
    ]

    standard_deck ++ jokers
  end

  @doc """
  Shuffles a deck of cards.

  ## Examples

      iex> deck = GanDengYan.Game.Deck.new()
      iex> shuffled = GanDengYan.Game.Deck.shuffle(deck)
      iex> length(shuffled)
      54
      iex> deck != shuffled
      true
  """
  @spec shuffle(t()) :: t()
  def shuffle(deck) do
    Enum.shuffle(deck)
  end

  @doc """
  Deals cards from the deck to the specified number of players.

  Returns a tuple with the list of hands and the remaining deck.

  ## Examples

      iex> deck = GanDengYan.Game.Deck.new()
      iex> {hands, remaining} = GanDengYan.Game.Deck.deal(deck, 4)
      iex> length(hands)
      4
      iex> Enum.all?(hands, fn hand -> length(hand) == 13 end)
      true
      iex> length(remaining)
      2
  """
  @spec deal(t(), non_neg_integer(), non_neg_integer()) :: {[[Card.t()]], t()}
  def deal(deck, num_players, cards_per_player) do
    deck
    |> Enum.take(num_players * cards_per_player)
    |> Enum.chunk_every(cards_per_player)
    |> then(fn hands -> {hands, Enum.drop(deck, num_players * cards_per_player)} end)
  end
end
