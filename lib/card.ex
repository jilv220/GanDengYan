defmodule Card do
  @type suit :: :hearts | :clubs | :diamonds | :spades
  @type face :: :jack | :queen | :king | :ace | :joker | 2..10
  @type t :: %Card{suit: suit(), face: face(), value: integer()}
  defstruct suit: nil, face: nil, value: 0

  @card_order %{
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
    :joker => 16
  }

  @spec to_string(t()) :: String.t()
  def to_string(%Card{suit: suit, face: face}) do
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
        # For jokers
        _ -> ""
      end

    if face == :joker do
      "#{face_str}"
    else
      "#{face_str}#{suit_str}"
    end
  end

  @spec value(t()) :: integer()
  def value(%Card{face: face}) do
    Map.get(@card_order, face, 0)
  end

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

defmodule CardPattern do
  @type t :: %CardPattern{
          type: :single | :pair | :triplet | :sequence | :bomb | :straight | :invalid,
          cards: [Card.t()],
          value: integer()
        }

  defstruct type: :invalid, cards: [], value: 0

  # Identify the type of pattern from a list of cards
  @spec identify([Card.t()]) :: t()
  def identify(cards) do
    sorted_cards = Enum.sort_by(cards, &Card.value/1, :desc)

    pattern =
      cond do
        is_single(sorted_cards) ->
          %CardPattern{type: :single, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_pair(sorted_cards) ->
          %CardPattern{type: :pair, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_triplet(sorted_cards) ->
          %CardPattern{type: :triplet, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_bomb(sorted_cards) ->
          %CardPattern{type: :bomb, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_straight(sorted_cards) ->
          %CardPattern{type: :straight, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        is_sequence(sorted_cards) ->
          %CardPattern{type: :sequence, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

        true ->
          %CardPattern{type: :invalid, cards: sorted_cards, value: 0}
      end

    IO.puts("Debug: Identified pattern type: #{pattern.type}, value: #{pattern.value}")
    pattern
  end

  # Check if pattern can beat previous pattern
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
        IO.puts("Debug: Comparing #{pattern.value} > #{prev_pattern.value}")
        pattern.value > prev_pattern.value

      true ->
        false
    end
  end

  # Pattern checkers
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
    # All pairs
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

  defp highest_card(cards) do
    Enum.max_by(cards, &Card.value/1)
  end

  # Format pattern for display
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
end
