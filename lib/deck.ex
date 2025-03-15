defmodule Deck do
  @type t :: [Card.t()]

  @spec make() :: t()
  def make() do
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
end
