defmodule GanDengYan.Game.CardPattern do
  @moduledoc """
  Identifies and validates card patterns/combinations in the GanDengYan game.

  Valid patterns include:
  - Single card
  - Pair (two of same face)
  - Triplet (three of same face)
  - Bomb (four of same face)
  - Sequence (consecutive faces)
  - Straight (consecutive pairs)
  """

  alias GanDengYan.Game.Card

  @type pattern_type :: :single | :pair | :triplet | :sequence | :bomb | :straight | :invalid
  @type t :: %__MODULE__{
          type: pattern_type(),
          cards: [Card.t()],
          value: integer()
        }

  defstruct type: :invalid, cards: [], value: 0

  @doc """
  Identifies the pattern type from a list of cards.

  Returns a CardPattern struct with the identified type, cards, and value.
  """
  @spec identify([Card.t()]) :: t()
  def identify(cards) do
    sorted_cards = Enum.sort_by(cards, &Card.value/1, :desc)

    pattern =
      cond do
        is_single(sorted_cards) ->
          %__MODULE__{type: :single, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_pair(sorted_cards) ->
          %__MODULE__{type: :pair, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_triplet(sorted_cards) ->
          %__MODULE__{type: :triplet, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_bomb(sorted_cards) ->
          %__MODULE__{type: :bomb, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_straight(sorted_cards) ->
          %__MODULE__{type: :straight, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_sequence(sorted_cards) ->
          %__MODULE__{type: :sequence, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        true ->
          %__MODULE__{type: :invalid, cards: sorted_cards, value: 0}
      end

    pattern
  end

  @doc """
  Determines if a pattern can beat a previous pattern according to game rules.

  Rules:
  - A pattern can only beat a pattern of the same type (except bombs)
  - Bombs can beat any pattern
  - Within the same type, higher value wins
  """
  @spec can_beat(t(), t()) :: boolean()
  def can_beat(pattern, prev_pattern) do
    cond do
      # Can't beat with different type unless it's a bomb
      pattern.type != prev_pattern.type and pattern.type != :bomb ->
        false

      # Bomb beats everything
      pattern.type == :bomb and prev_pattern.type != :bomb ->
        true

      # Compare values for same type
      pattern.type == prev_pattern.type ->
        pattern.value > prev_pattern.value

      true ->
        false
    end
  end

  @doc """
  Converts a pattern to its string representation.
  """
  @spec to_string(t()) :: String.t()
  def to_string(pattern) do
    cards_str =
      pattern.cards
      |> Enum.map(&Card.to_string/1)
      |> Enum.join(", ")

    type_str =
      case pattern.type do
        :single -> "Single"
        :pair -> "Pair"
        :triplet -> "Three of a kind"
        :bomb -> "Bomb"
        :straight -> "Straight pairs"
        :sequence -> "Sequence"
        :invalid -> "Invalid pattern"
      end

    "#{type_str}: #{cards_str}"
  end

  # Pattern validation functions
  defp is_single(cards) when length(cards) == 1, do: true
  defp is_single(_), do: false

  defp is_pair(cards) when length(cards) == 2 do
    [card1, card2] = cards
    card1.face == card2.face
  end

  defp is_pair(_), do: false

  defp is_triplet(cards) when length(cards) == 3 do
    [card1, card2, card3] = cards
    card1.face == card2.face and card2.face == card3.face
  end

  defp is_triplet(_), do: false

  defp is_bomb(cards) when length(cards) == 4 do
    [card1, card2, card3, card4] = cards
    card1.face == card2.face and card2.face == card3.face and card3.face == card4.face
  end

  defp is_bomb(_), do: false

  defp is_sequence(cards) when length(cards) >= 3 do
    cards
    |> Enum.sort_by(&Card.value/1)
    |> check_consecutive()
  end

  defp is_sequence(_), do: false

  defp is_straight(cards) when length(cards) >= 3 do
    # Group by face values
    faces = cards |> Enum.map(& &1.face)
    # Must have at least 3 cards, all pairs
    length(cards) >= 3 and
      length(cards) == length(Enum.uniq(faces)) * 2 and
      faces
      |> Enum.uniq()
      |> Enum.sort()
      |> check_consecutive()
  end

  defp is_straight(_), do: false

  defp check_consecutive(sorted_values) do
    sorted_values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> b - a == 1 end)
  end
end
