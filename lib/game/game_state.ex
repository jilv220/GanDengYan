defmodule GanDengYan.Game.GameState do
  @moduledoc """
  Represents the state of a GanDengYan game.

  This module contains the game state struct and functions to manipulate it.
  """

  alias GanDengYan.Game.{Player, CardPattern, Deck}

  @type t :: %__MODULE__{
          players: [Player.t()],
          current_player_idx: non_neg_integer(),
          started: boolean(),
          last_play: CardPattern.t() | nil,
          last_valid_play: CardPattern.t() | nil,
          last_valid_player_idx: non_neg_integer() | nil,
          passes: non_neg_integer(),
          winner: String.t() | nil,
          deck: Deck.t()
        }

  defstruct players: [],
            current_player_idx: 0,
            started: false,
            last_play: nil,
            last_valid_play: nil,
            last_valid_player_idx: nil,
            passes: 0,
            winner: nil,
            deck: []

  @doc """
  Creates a new game state.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Adds a player to the game.

  Returns {:ok, updated_state} if successful, or
  {:error, reason} if the player can't be added.
  """
  @spec add_player(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def add_player(%__MODULE__{started: true}, _player_name) do
    IO.puts("Cannot add player: game is already in progress")
    {:error, :game_in_progress}
  end

  def add_player(state, player_name) do
    if Enum.any?(state.players, &(&1.name == player_name)) do
      IO.puts("Cannot add player '#{player_name}': name is already taken")
      {:error, :name_taken}
    else
      # First player to join is the banker
      is_banker = Enum.empty?(state.players)
      new_player = Player.new(player_name, is_banker)
      new_state = %__MODULE__{state | players: state.players ++ [new_player]}

      IO.puts(
        "Added player '#{player_name}' to the game. Total players: #{length(new_state.players)}"
      )

      {:ok, new_state}
    end
  end

  @doc """
  Starts the game by dealing cards to players.

  Returns {:ok, updated_state} if successful, or
  {:error, reason} if the game can't be started.
  """
  @spec start_game(t()) :: {:ok, t()} | {:error, atom()}
  def start_game(%__MODULE__{started: true}) do
    {:error, :game_already_started}
  end

  def start_game(%__MODULE__{players: players} = _state) when length(players) < 2 do
    {:error, :not_enough_players}
  end

  def start_game(%__MODULE__{players: players} = state) do
    # Create and shuffle a new deck
    deck = Deck.new() |> Deck.shuffle()

    # Deal cards to players (banker gets 7, others get 6)
    {players_with_cards, remaining_deck} =
      Enum.map_reduce(players, deck, fn player, remaining_deck ->
        cards_to_deal = if player.is_banker, do: 7, else: 6
        {cards, new_deck} = Enum.split(remaining_deck, cards_to_deal)
        {Player.add_cards(player, cards), new_deck}
      end)

    # Find banker index (first player is banker by default)
    banker_idx = Enum.find_index(players_with_cards, & &1.is_banker) || 0

    new_state = %__MODULE__{
      state
      | players: players_with_cards,
        current_player_idx: banker_idx,
        started: true,
        deck: remaining_deck
    }

    {:ok, new_state}
  end

  @doc """
  Handles a player's attempt to play cards.

  Returns:
  - {:ok, :card_played, pattern, state} if successful
  - {:ok, :game_over, winner, state} if the player wins
  - {:error, reason, state} if the play is invalid
  """
  @spec play_cards(t(), String.t(), [non_neg_integer()]) ::
          {:ok, :card_played, CardPattern.t(), t()}
          | {:ok, :game_over, String.t(), t()}
          | {:error, atom(), t()}
  def play_cards(%__MODULE__{started: false} = state, _player_name, _card_indices) do
    {:error, :game_not_started, state}
  end

  def play_cards(state, player_name, card_indices) do
    # Find the player
    player_idx = Enum.find_index(state.players, &(&1.name == player_name))

    cond do
      # Player not found
      is_nil(player_idx) ->
        {:error, :player_not_found, state}

      # Not this player's turn
      player_idx != state.current_player_idx ->
        {:error, :not_your_turn, state}

      # Process the play
      true ->
        player = Enum.at(state.players, player_idx)

        # Check if card indices are valid
        if Enum.any?(card_indices, &(&1 < 0 or &1 >= length(player.hand))) do
          {:error, :invalid_card_indices, state}
        else
          # Get the selected cards
          {updated_player, selected_cards} = Player.remove_cards(player, card_indices)

          # Identify pattern
          pattern = CardPattern.identify(selected_cards)

          cond do
            # Invalid pattern
            pattern.type == :invalid ->
              {:error, :invalid_pattern, state}

            # Must beat previous pattern if not first play
            not is_nil(state.last_valid_play) and
                not CardPattern.can_beat(pattern, state.last_valid_play) ->
              {:error, :cannot_beat_last_play, state}

            # Valid play
            true ->
              updated_players = List.replace_at(state.players, player_idx, updated_player)

              # Check if player has won
              if Enum.empty?(updated_player.hand) do
                # Game over, player has won
                new_state = %__MODULE__{
                  state
                  | players: updated_players,
                    winner: player_name
                }

                {:ok, :game_over, player_name, new_state}
              else
                # Update game state and move to next player
                next_player_idx = rem(player_idx + 1, length(state.players))

                new_state = %__MODULE__{
                  state
                  | players: updated_players,
                    current_player_idx: next_player_idx,
                    last_play: pattern,
                    last_valid_play: pattern,
                    last_valid_player_idx: player_idx,
                    passes: 0
                }

                {:ok, :card_played, pattern, new_state}
              end
          end
        end
    end
  end

  @doc """
  Handles a player's attempt to pass.

  Returns:
  - {:ok, :passed, state} if successful
  - {:ok, :everyone_passed, last_player_idx, state} if everyone has passed
  - {:error, reason, state} if the pass is invalid
  """
  @spec pass(t(), String.t()) ::
          {:ok, :passed, t()}
          | {:ok, :everyone_passed, non_neg_integer(), t()}
          | {:error, atom(), t()}
  def pass(%__MODULE__{started: false} = state, _player_name) do
    {:error, :game_not_started, state}
  end

  def pass(state, player_name) do
    # Find the player
    player_idx = Enum.find_index(state.players, &(&1.name == player_name))

    cond do
      # Player not found
      is_nil(player_idx) ->
        {:error, :player_not_found, state}

      # Not this player's turn
      player_idx != state.current_player_idx ->
        {:error, :not_your_turn, state}

      # Cannot pass if you're the first player or no valid play exists
      is_nil(state.last_valid_play) ->
        {:error, :cannot_pass_first_play, state}

      # Process the pass
      true ->
        next_player_idx = rem(player_idx + 1, length(state.players))
        passes = state.passes + 1

        # If everyone except the last valid player has passed, reset
        if passes >= length(state.players) - 1 do
          # Find the player who made the last valid play
          last_player_idx = state.last_valid_player_idx

          if is_nil(last_player_idx) do
            # If we can't find that player, just go to the next
            new_state = %__MODULE__{
              state
              | current_player_idx: next_player_idx,
                last_play: nil,
                last_valid_play: nil,
                last_valid_player_idx: nil,
                passes: 0
            }

            {:ok, :everyone_passed, new_state}
          else
            # Award a card to the last player who played a valid pattern
            last_player = Enum.at(state.players, last_player_idx)
            {card, rest_deck} = List.pop_at(state.deck, 0)

            updated_player =
              if is_nil(card) do
                # If deck is empty, just continue
                last_player
              else
                Player.add_cards(last_player, [card])
              end

            updated_players = List.replace_at(state.players, last_player_idx, updated_player)

            new_state = %__MODULE__{
              state
              | players: updated_players,
                deck: rest_deck,
                current_player_idx: last_player_idx,
                last_play: nil,
                last_valid_play: nil,
                last_valid_player_idx: nil,
                passes: 0
            }

            {:ok, :everyone_passed, last_player_idx, new_state}
          end
        else
          # Just a normal pass
          new_state = %__MODULE__{
            state
            | current_player_idx: next_player_idx,
              passes: passes
          }

          {:ok, :passed, new_state}
        end
    end
  end

  @doc """
  Returns a string representation of the current game state.

  This is used for displaying the game state to players.
  """
  @spec to_string(t()) :: String.t()
  def to_string(state) do
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
        "\nLast play: #{CardPattern.to_string(state.last_valid_play)}"
      else
        "\nNo plays yet"
      end

    "\n=== Current Game State ===\n#{players_str}#{last_play_str}\n"
  end
end
