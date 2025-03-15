defmodule GanDengYan.Game.Player do
  @moduledoc """
  Represents a player in the GanDengYan card game.

  Each player has a name, a hand of cards, and a flag indicating
  whether they are the banker (dealer).
  """

  alias GanDengYan.Game.Card

  @type t :: %__MODULE__{
          name: String.t(),
          hand: [Card.t()],
          is_banker: boolean()
        }

  defstruct name: "", hand: [], is_banker: false

  @doc """
  Creates a new player with the given name.

  ## Examples

      iex> GanDengYan.Game.Player.new("Player 1")
      %GanDengYan.Game.Player{name: "Player 1", hand: [], is_banker: false}
  """
  @spec new(String.t(), boolean()) :: t()
  def new(name, is_banker \\ false) do
    %__MODULE__{name: name, is_banker: is_banker}
  end

  @doc """
  Adds cards to a player's hand.

  ## Examples

      iex> player = GanDengYan.Game.Player.new("Player 1")
      iex> card = %GanDengYan.Game.Card{suit: :hearts, face: :ace}
      iex> updated = GanDengYan.Game.Player.add_cards(player, [card])
      iex> updated.hand
      [%GanDengYan.Game.Card{suit: :hearts, face: :ace}]
  """
  @spec add_cards(t(), [Card.t()]) :: t()
  def add_cards(player, cards) do
    %__MODULE__{player | hand: player.hand ++ cards}
  end

  @doc """
  Removes cards from a player's hand by indices.

  Returns an updated player and the removed cards.

  ## Examples

      iex> player = GanDengYan.Game.Player.new("Player 1")
      iex> player = %{player | hand: [
      ...>   %GanDengYan.Game.Card{suit: :hearts, face: :ace},
      ...>   %GanDengYan.Game.Card{suit: :spades, face: :king},
      ...>   %GanDengYan.Game.Card{suit: :clubs, face: :queen}
      ...> ]}
      iex> {updated, removed} = GanDengYan.Game.Player.remove_cards(player, [0, 2])
      iex> length(updated.hand)
      1
      iex> length(removed)
      2
  """
  @spec remove_cards(t(), [non_neg_integer()]) :: {t(), [Card.t()]}
  def remove_cards(player, indices) do
    # Get the cards to remove
    cards_to_remove = Enum.map(indices, &Enum.at(player.hand, &1))

    # Create a new hand without those cards
    remaining_indices = for i <- 0..(length(player.hand) - 1), not Enum.member?(indices, i), do: i
    remaining_cards = Enum.map(remaining_indices, &Enum.at(player.hand, &1))

    {%__MODULE__{player | hand: remaining_cards}, cards_to_remove}
  end

  @doc """
  Sorts a player's hand for display.

  Cards are sorted by value (highest first) and then by suit.

  ## Examples

      iex> player = GanDengYan.Game.Player.new("Player 1")
      iex> player = %{player | hand: [
      ...>   %GanDengYan.Game.Card{suit: :diamonds, face: 7},
      ...>   %GanDengYan.Game.Card{suit: :hearts, face: :ace},
      ...>   %GanDengYan.Game.Card{suit: :spades, face: 7}
      ...> ]}
      iex> sorted = GanDengYan.Game.Player.sort_hand(player)
      iex> hd(sorted.hand).face
      :ace
  """
  @spec sort_hand(t()) :: t()
  def sort_hand(player) do
    sorted_hand = Enum.sort_by(player.hand, fn card -> {-Card.value(card), card.suit} end)
    %__MODULE__{player | hand: sorted_hand}
  end

  @doc """
  Returns a string representation of a player's hand.

  ## Examples

      iex> player = GanDengYan.Game.Player.new("Player 1")
      iex> player = %{player | hand: [
      ...>   %GanDengYan.Game.Card{suit: :hearts, face: :ace},
      ...>   %GanDengYan.Game.Card{suit: :spades, face: :king}
      ...> ]}
      iex> GanDengYan.Game.Player.hand_to_string(player)
      "Player 1's hand: A♥, K♠ (2 cards)"
  """
  @spec hand_to_string(t()) :: String.t()
  def hand_to_string(player) do
    cards_str =
      player
      |> sort_hand()
      |> Map.get(:hand)
      |> Enum.map(&Card.to_string/1)
      |> Enum.join(", ")

    "#{player.name}'s hand: #{cards_str} (#{length(player.hand)} cards)"
  end
end
