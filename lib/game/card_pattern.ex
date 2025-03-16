defmodule GanDengYan.Game.CardPattern do
  @moduledoc """
  Identifies and validates card patterns/combinations in the GanDengYan game.

  Valid patterns include:
  - Single card
  - Pair (two of same face)
  - Bomb (three of same face, or a pair of jokers)
  - Abomb (four of same face)
  - Sequence (consecutive faces), must be 3 cards
  - Straight (consecutive pairs), must be 4 cards, two consecutive pairs
  """

  alias GanDengYan.Game.Card

  @type pattern_type :: :single | :pair | :bomb | :sequence | :abomb | :straight | :invalid
  @type t :: %__MODULE__{
          type: pattern_type(),
          cards: [Card.t()],
          value: integer()
        }

  defstruct type: :invalid, cards: [], value: 0

  @doc """
  Identifies the pattern type from a list of cards.

  Returns a CardPattern struct with the identified type, cards, and value.

  Pattern recognition priority:
  1. ABomb (four of a kind) - highest priority
  2. Bomb (three of a kind)
  3. Straight (consecutive pairs)
  4. Sequence (consecutive cards)
  5. Pair
  6. Single

  When jokers are present, they will preferentially complete the highest-ranked pattern possible.
  A pair of jokers is considered a bomb.
  """
  @spec identify([Card.t()]) :: t()
  def identify(cards) do
    sorted_cards = Enum.sort_by(cards, &Card.value/1, :desc)

    pattern =
      cond do
        # Special case: a pair of jokers is a bomb
        is_joker_pair_bomb(sorted_cards) ->
          value = Card.value(%Card{face: :joker})
          %__MODULE__{type: :bomb, cards: sorted_cards, value: value}

        is_abomb(sorted_cards) ->
          value = get_pattern_value_with_jokers(sorted_cards, :abomb)
          %__MODULE__{type: :abomb, cards: sorted_cards, value: value}

        is_bomb(sorted_cards) ->
          value = get_pattern_value_with_jokers(sorted_cards, :bomb)
          %__MODULE__{type: :bomb, cards: sorted_cards, value: value}

        is_straight(sorted_cards) ->
          value = get_pattern_value_with_jokers(sorted_cards, :straight)
          %__MODULE__{type: :straight, cards: sorted_cards, value: value}

        is_sequence(sorted_cards) ->
          value = get_pattern_value_with_jokers(sorted_cards, :sequence)
          %__MODULE__{type: :sequence, cards: sorted_cards, value: value}

        is_pair(sorted_cards) ->
          value = get_pattern_value_with_jokers(sorted_cards, :pair)
          %__MODULE__{type: :pair, cards: sorted_cards, value: value}

        is_single(sorted_cards) ->
          %__MODULE__{type: :single, cards: sorted_cards, value: Card.value(hd(sorted_cards))}

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
      # Can't beat with different type unless it's a bomb or abomb
      pattern.type != prev_pattern.type and
        pattern.type != :bomb and
          pattern.type != :abomb ->
        false

      # Bomb or Abomb beats everything
      pattern.type in [:bomb, :abomb] and
          prev_pattern.type not in [:bomb, :abomb] ->
        true

      # Abomb beats any bomb
      pattern.type == :abomb and prev_pattern.type == :bomb ->
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
        :bomb -> "Bomb"
        :abomb -> "Atomic Bomb"
        :straight -> "Straight pairs"
        :sequence -> "Sequence"
        :invalid -> "Invalid pattern"
      end

    "#{type_str}: #{cards_str}"
  end

  ### Pattern validation functions

  ## Joker
  defp is_joker(%Card{face: :joker}), do: true
  defp is_joker(_), do: false

  ## Special case for joker pair as bomb
  defp is_joker_pair_bomb(cards) when length(cards) == 2 do
    Enum.all?(cards, &is_joker/1)
  end

  defp is_joker_pair_bomb(_), do: false

  ## Single
  # Jokers can't be played as singles
  defp is_single([%Card{face: :joker}]), do: false
  defp is_single(cards) when length(cards) == 1, do: true
  defp is_single(_), do: false

  # Pair
  defp is_pair(cards) when length(cards) == 2 do
    [card1, card2] = cards
    # If both are jokers, they're considered a bomb, not a pair
    case {is_joker(card1), is_joker(card2)} do
      # A pair of jokers is now a bomb
      {true, true} -> false
      {true, false} -> true
      {false, true} -> true
      {false, false} -> card1.face == card2.face
    end
  end

  defp is_pair(_), do: false

  ## Bomb
  defp is_bomb(cards) when length(cards) == 3 do
    [card1, card2, card3] = cards
    joker_count = Enum.count(cards, &is_joker/1)

    cond do
      joker_count == 3 ->
        true

      joker_count == 2 ->
        true

      joker_count == 1 ->
        regular_cards = Enum.reject(cards, &is_joker/1)
        [reg1, reg2] = regular_cards
        reg1.face == reg2.face

      joker_count == 0 ->
        card1.face == card2.face and card2.face == card3.face
    end
  end

  defp is_bomb(_), do: false

  ## Abomb
  defp is_abomb(cards) when length(cards) == 4 do
    joker_count = Enum.count(cards, &is_joker/1)

    cond do
      joker_count == 4 ->
        true

      joker_count == 3 ->
        true

      joker_count == 2 ->
        regular_cards = Enum.reject(cards, &is_joker/1)
        [reg1, reg2] = regular_cards
        reg1.face == reg2.face

      joker_count == 1 ->
        regular_cards = Enum.reject(cards, &is_joker/1)
        [reg1, reg2, reg3] = regular_cards
        reg1.face == reg2.face and reg2.face == reg3.face

      joker_count == 0 ->
        [card1, card2, card3, card4] = cards
        card1.face == card2.face and card2.face == card3.face and card3.face == card4.face
    end
  end

  defp is_abomb(_), do: false

  ## Sequence
  defp is_sequence(cards) when length(cards) == 3 do
    # For sequences with jokers, we need to make special handling
    # First, count jokers
    joker_count = Enum.count(cards, &is_joker/1)

    if joker_count == 0 do
      # Traditional check - sort and check for consecutive values
      cards
      |> Enum.map(&Card.value/1)
      |> Enum.sort()
      |> check_consecutive()
    else
      # With jokers, we need more complex logic
      # We'll extract regular cards and check if jokers can fill gaps
      regular_cards = Enum.reject(cards, &is_joker/1)

      # Too many jokers would make any combination valid, so we limit
      if joker_count > length(cards) / 2 do
        # If more than half are jokers, we can make any sequence
        true
      else
        # Sort regular cards by value
        sorted_values =
          Enum.sort_by(regular_cards, &Card.value/1)
          |> Enum.map(&Card.value/1)

        # Check if we can make a valid sequence with the jokers
        can_form_sequence_with_jokers(sorted_values, joker_count, length(cards))
      end
    end
  end

  defp is_sequence(_), do: false

  ## Straight
  defp is_straight(cards) when length(cards) == 4 do
    # A straight is consecutive pairs
    # Group cards by face, counting jokers separately
    card_groups =
      Enum.group_by(cards, fn
        %Card{face: :joker} -> :joker
        card -> card.face
      end)

    jokers = Map.get(card_groups, :joker, [])
    joker_count = length(jokers)

    # Remove jokers from the grouping
    card_groups = Map.delete(card_groups, :joker)

    # Check if we can form valid pairs
    pairs_needed = length(cards) / 2
    complete_pairs = Enum.count(card_groups, fn {_, group} -> length(group) == 2 end)
    single_cards = Enum.count(card_groups, fn {_, group} -> length(group) == 1 end)

    jokers_remaining = joker_count

    # Use jokers to complete single cards into pairs
    singles_that_can_be_completed = min(single_cards, jokers_remaining)
    jokers_remaining = jokers_remaining - singles_that_can_be_completed

    # Use remaining jokers to form new pairs (2 jokers = 1 pair)
    new_pairs_from_jokers = div(jokers_remaining, 2)

    total_pairs = complete_pairs + singles_that_can_be_completed + new_pairs_from_jokers

    if total_pairs == pairs_needed do
      # Now check if these pairs can form a consecutive sequence
      faces = Map.keys(card_groups) ++ List.duplicate(:joker_pair, new_pairs_from_jokers)

      # Sort faces and check if they can form a consecutive sequence
      can_form_consecutive_with_jokers(
        Enum.map(faces, &face_to_value/1),
        singles_that_can_be_completed,
        jokers_remaining - new_pairs_from_jokers * 2
      )
    else
      false
    end
  end

  defp is_straight(_), do: false

  ### Helpers

  defp face_to_value(:joker_pair), do: -1

  defp face_to_value(face) do
    %Card{face: face, suit: :hearts} |> Card.value()
  end

  defp check_consecutive(sorted_values) do
    sorted_values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> b - a == 1 end)
  end

  # Helper to determine if a sequence can be formed with jokers
  defp can_form_sequence_with_jokers(values, joker_count, target_length) do
    # For an empty list of values, we can form a sequence with only jokers
    if Enum.empty?(values) do
      joker_count >= target_length
    else
      # If only one regular card, we can always form a sequence with enough jokers
      if length(values) == 1 do
        joker_count >= target_length - 1
      else
        # Sort values to ensure they're in ascending order
        sorted_values = Enum.sort(values)

        # Calculate gaps between consecutive cards
        gaps =
          Enum.zip(sorted_values, Enum.drop(sorted_values, 1))
          |> Enum.map(fn {a, b} -> b - a - 1 end)
          |> Enum.sum()

        # Calculate missing cards at the beginning and end to reach target length
        total_existing = length(values)
        needed_jokers = gaps + (target_length - total_existing - gaps)

        # Check if we have enough jokers to fill all needed positions
        joker_count >= needed_jokers
      end
    end
  end

  # Helper to determine if consecutive pairs can be formed with jokers
  defp can_form_consecutive_with_jokers(values, singles_using_jokers, remaining_jokers) do
    # Sort and remove placeholder values
    real_values = Enum.reject(values, &(&1 == -1)) |> Enum.sort()

    if length(real_values) <= 1 do
      # With 0 or 1 real values, we can form any sequence with enough jokers
      true
    else
      # Check for gaps between real values
      gaps =
        Enum.zip(real_values, Enum.drop(real_values, 1))
        |> Enum.map(fn {a, b} -> b - a - 1 end)
        |> Enum.sum()

      # We need jokers to fill these gaps
      remaining_jokers + singles_using_jokers >= gaps
    end
  end

  defp get_pattern_value_with_jokers(cards, pattern_type) do
    # For a pattern with jokers, the value is determined by the non-joker cards
    regular_cards = Enum.reject(cards, &is_joker/1)
    jokers = Enum.filter(cards, &is_joker/1)

    cond do
      # If all cards are jokers, use the joker value
      Enum.empty?(regular_cards) ->
        Card.value(%Card{face: :joker})

      # Special case for sequences with jokers at the end
      pattern_type == :sequence && hd(cards).face == :joker &&
          (List.last(cards).face == :joker || length(jokers) > 1) ->
        # When sequence has joker at the highest position, use joker value
        Card.value(%Card{face: :joker})

      # For pairs, bombs, abombs - use the value of the regular card
      pattern_type in [:pair, :bomb, :abomb] ->
        # The value comes from the highest regular card
        hd(Enum.sort_by(regular_cards, &Card.value/1, :desc)) |> Card.value()

      # For sequences and straights, use the highest card's value
      pattern_type in [:sequence, :straight] ->
        # Sort regular cards and get the highest value
        hd(Enum.sort_by(regular_cards, &Card.value/1, :desc)) |> Card.value()

      # Default case
      true ->
        # Highest card value
        Card.value(hd(cards))
    end
  end
end
