defmodule GanDengYan.UI.Formatter do
  @moduledoc """
  Functions for formatting game data for display.

  This module handles all text formatting for the UI.
  """

  alias GanDengYan.Game.{Card, CardPattern, Player}

  @doc """
  Formats the game state for display.
  """
  @spec format_game_state(map()) :: String.t()
  def format_game_state(state) do
    # Format player info
    players_str =
      state.players
      |> Enum.map(fn player ->
        is_current = Enum.at(state.players, state.current_player_idx).name == player.name
        current_marker = if is_current, do: "-> ", else: "   "
        banker_marker = if player.is_banker, do: " (Banker)", else: ""
        "#{current_marker}#{player.name}: #{length(player.hand)} cards#{banker_marker}"
      end)
      |> Enum.join("\n")

    # Format last play
    last_play_str =
      if state.last_valid_play do
        "\nLast play: #{format_pattern(state.last_valid_play)}"
      else
        "\nNo plays yet"
      end

    "\n=== Current Game State ===\n#{players_str}#{last_play_str}\n"
  end

  @doc """
  Formats a player's hand with indices for selection in a compact way.

  Returns a tuple with the formatted string and a map of display indices to actual indices.
  """
  @spec format_hand_for_selection(Player.t()) :: {String.t(), map()}
  def format_hand_for_selection(player) do
    # Sort the cards for display
    sorted_hand = Enum.sort_by(player.hand, fn card -> {-Card.value(card), card.suit} end)

    # Create a mapping from display indices to actual hand indices
    index_map =
      sorted_hand
      |> Enum.with_index()
      |> Enum.map(fn {card, sorted_idx} ->
        actual_idx = Enum.find_index(player.hand, fn c -> c == card end)
        {sorted_idx, actual_idx}
      end)
      |> Map.new()

    # Format the hand for display in a compact way
    cards_with_indices =
      sorted_hand
      |> Enum.with_index()
      |> Enum.map(fn {card, idx} ->
        "#{idx}:#{Card.to_string(card)}"
      end)

    # Group cards into rows of 5 for more compact display
    rows =
      cards_with_indices
      |> Enum.chunk_every(5)
      |> Enum.map(fn chunk -> Enum.join(chunk, "  ") end)
      |> Enum.join("\n")

    {rows, index_map}
  end

  @doc """
  Formats the prompt for player input during their turn.
  """
  @spec format_play_prompt(map()) :: String.t()
  def format_play_prompt(state) do
    if is_nil(state.last_valid_play) do
      "\nYou're first to play! Select cards to play:\n> "
    else
      "\nLast played: #{format_pattern(state.last_valid_play)}\n\nSelect cards to play (or type 'pass' to pass):\n> "
    end
  end

  @doc """
  Formats a card pattern for display.
  """
  @spec format_pattern(CardPattern.t()) :: String.t()
  def format_pattern(pattern) do
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

  @doc """
  Formats error messages for display.
  """
  @spec format_error(atom()) :: String.t()
  def format_error(reason) do
    case reason do
      :invalid_pattern ->
        "The selected cards don't form a valid pattern."

      :cannot_beat_last_play ->
        "Your play cannot beat the last play. Try higher cards of same type or a bomb."

      :invalid_card_indices ->
        "One or more card indices are invalid."

      :name_taken ->
        "That name is already taken."

      :game_in_progress ->
        "The game is already in progress."

      :not_your_turn ->
        "It's not your turn."

      :not_enough_players ->
        "Need at least 2 players to start the game."

      :game_already_started ->
        "The game has already started."

      :game_not_started ->
        "The game hasn't started yet."

      :cannot_pass_first_play ->
        "You cannot pass on the first play."

      _ ->
        to_string(reason)
    end
  end
end
