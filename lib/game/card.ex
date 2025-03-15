defmodule GanDengYan.Game.Card do
  @moduledoc """
  Representation of a playing card in the GanDengYan game.

  Each card has a suit and face value. The game uses a standard deck
  plus jokers.
  """

  @type suit :: :hearts | :clubs | :diamonds | :spades | nil
  @type face :: :jack | :queen | :king | :ace | :joker | 2..10
  @type t :: %__MODULE__{suit: suit(), face: face()}

  defstruct suit: nil, face: nil

  @card_values %{
    # 2 is special in this game
    2 => 15,
    3 => 3,
    4 => 4,
    5 => 5,
    6 => 6,
    7 => 7,
    8 => 8,
    9 => 9,
    10 => 10,
    :jack => 11,
    :queen => 12,
    :king => 13,
    :ace => 14,
    # Joker is highest
    :joker => 16
  }

  @doc """
  Returns a string representation of a card.

  ## Examples

      iex> GanDengYan.Game.Card.to_string(%GanDengYan.Game.Card{suit: :hearts, face: :ace})
      "A♥"

      iex> GanDengYan.Game.Card.to_string(%GanDengYan.Game.Card{suit: nil, face: :joker})
      "Joker"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{suit: suit, face: face}) do
    face_str =
      case face do
        :jack -> "J"
        :queen -> "Q"
        :king -> "K"
        :ace -> "A"
        :joker -> "Joker"
        _ -> Integer.to_string(face)
      end

    suit_str =
      case suit do
        :hearts -> "♥"
        :diamonds -> "♦"
        :clubs -> "♣"
        :spades -> "♠"
        _ -> ""
      end

    if face == :joker do
      "#{face_str}"
    else
      "#{face_str}#{suit_str}"
    end
  end

  @doc """
  Returns the numeric value of a card for comparison.

  ## Examples

      iex> GanDengYan.Game.Card.value(%GanDengYan.Game.Card{suit: :hearts, face: :ace})
      14
  """
  @spec value(t()) :: integer()
  def value(%__MODULE__{face: face}) do
    Map.get(@card_values, face, 0)
  end

  @doc """
  Compares two cards, returning :gt, :lt, or :eq.

  ## Examples

      iex> card1 = %GanDengYan.Game.Card{suit: :hearts, face: :ace}
      iex> card2 = %GanDengYan.Game.Card{suit: :spades, face: :king}
      iex> GanDengYan.Game.Card.compare(card1, card2)
      :gt
  """
  @spec compare(t(), t()) :: :gt | :lt | :eq
  def compare(card1, card2) do
    value1 = value(card1)
    value2 = value(card2)

    cond do
      value1 > value2 -> :gt
      value1 < value2 -> :lt
      true -> :eq
    end
  end
end
