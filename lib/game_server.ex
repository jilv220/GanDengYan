defmodule GanDengYan.GameServer do
  use GenServer

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def join(server, player_name) do
    GenServer.call(server, {:join, player_name})
  end

  def start_game(server) do
    GenServer.call(server, :start_game)
  end

  def play_cards(server, player_name, card_indices) do
    GenServer.call(server, {:play_cards, player_name, card_indices})
  end

  def pass(server, player_name) do
    GenServer.call(server, {:pass, player_name})
  end

  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  # Server callbacks
  @impl true
  def init(:ok) do
    {:ok,
     %{
       players: [],
       current_player_idx: 0,
       started: false,
       last_play: nil,
       last_valid_play: nil,
       passes: 0,
       winner: nil
     }}
  end

  @impl true
  def handle_call({:join, player_name}, _from, %{started: false} = state) do
    if Enum.any?(state.players, &(&1.name == player_name)) do
      {:reply, {:error, :name_taken}, state}
    else
      # First player to join is the banker
      is_banker = Enum.empty?(state.players)
      new_player = %Player{name: player_name, is_banker: is_banker}
      new_state = %{state | players: state.players ++ [new_player]}
      {:reply, {:ok, new_player}, new_state}
    end
  end

  @impl true
  def handle_call({:join, _player_name}, _from, %{started: true} = state) do
    {:reply, {:error, :game_in_progress}, state}
  end

  @impl true
  def handle_call(:start_game, _from, %{started: false} = state) do
    if length(state.players) < 2 do
      {:reply, {:error, :not_enough_players}, state}
    else
      # Deal cards
      deck = Deck.make() |> Dealer.shuffle()
      {players_with_cards, _} = Dealer.deal(deck, state.players)

      # Find banker index
      banker_idx = Enum.find_index(players_with_cards, & &1.is_banker)

      new_state = %{
        state
        | players: players_with_cards,
          current_player_idx: banker_idx,
          started: true
      }

      {:reply, {:ok, new_state}, new_state}
    end
  end

  @impl true
  def handle_call(:start_game, _from, %{started: true} = state) do
    {:reply, {:error, :game_already_started}, state}
  end

  @impl true
  def handle_call({:play_cards, player_name, card_indices}, _from, state) do
    # Game must be started
    if not state.started do
      {:reply, {:error, :game_not_started}, state}
    else
      # Find the player
      player_idx = Enum.find_index(state.players, &(&1.name == player_name))

      cond do
        # Player not found
        is_nil(player_idx) ->
          {:reply, {:error, :player_not_found}, state}

        # Not this player's turn
        player_idx != state.current_player_idx ->
          {:reply, {:error, :not_your_turn}, state}

        # Process the play
        true ->
          player = Enum.at(state.players, player_idx)

          # Check if card indices are valid
          if Enum.any?(card_indices, &(&1 < 0 or &1 >= length(player.hand))) do
            {:reply, {:error, :invalid_card_indices}, state}
          else
            # Get the selected cards
            selected_cards = Enum.map(card_indices, &Enum.at(player.hand, &1))

            # Identify pattern
            pattern = CardPattern.identify(selected_cards)

            cond do
              # Invalid pattern
              pattern.type == :invalid ->
                {:reply, {:error, :invalid_pattern}, state}

              # Must beat previous pattern if not first play
              not is_nil(state.last_valid_play) and
                  not CardPattern.can_beat(pattern, state.last_valid_play) ->
                {:reply, {:error, :cannot_beat_last_play}, state}

              # Valid play
              true ->
                # Remove played cards from hand
                remaining_indices =
                  for i <- 0..(length(player.hand) - 1), not Enum.member?(card_indices, i), do: i

                remaining_cards = Enum.map(remaining_indices, &Enum.at(player.hand, &1))

                updated_player = %Player{player | hand: remaining_cards}
                updated_players = List.replace_at(state.players, player_idx, updated_player)

                # Check if player has won
                if length(remaining_cards) == 0 do
                  # Game over, player has won
                  new_state = %{
                    state
                    | players: updated_players,
                      winner: player_name
                  }

                  {:reply, {:ok, :game_over, player_name}, new_state}
                else
                  # Update game state and move to next player
                  next_player_idx = rem(player_idx + 1, length(state.players))

                  new_state = %{
                    state
                    | players: updated_players,
                      current_player_idx: next_player_idx,
                      last_play: pattern,
                      last_valid_play: pattern,
                      passes: 0
                  }

                  {:reply, {:ok, :card_played, pattern}, new_state}
                end
            end
          end
      end
    end
  end

  @impl true
  def handle_call({:pass, player_name}, _from, state) do
    # Game must be started
    if not state.started do
      {:reply, {:error, :game_not_started}, state}
    else
      # Find the player
      player_idx = Enum.find_index(state.players, &(&1.name == player_name))

      cond do
        # Player not found
        is_nil(player_idx) ->
          {:reply, {:error, :player_not_found}, state}

        # Not this player's turn
        player_idx != state.current_player_idx ->
          {:reply, {:error, :not_your_turn}, state}

        # Cannot pass if you're the first player or everyone else has passed
        is_nil(state.last_valid_play) ->
          {:reply, {:error, :cannot_pass_first_play}, state}

        # Process the pass
        true ->
          next_player_idx = rem(player_idx + 1, length(state.players))
          passes = state.passes + 1

          # If everyone except the last valid player has passed, reset
          if passes >= length(state.players) - 1 do
            # Find the player who made the last valid play
            last_player_idx =
              Enum.find_index(state.players, fn p ->
                Enum.find(p.hand, &(&1 == hd(state.last_valid_play.cards)))
              end)

            # If we can't find that player (cards have been played), just go to the next
            actual_next_idx =
              if is_nil(last_player_idx), do: next_player_idx, else: last_player_idx

            new_state = %{
              state
              | current_player_idx: actual_next_idx,
                last_play: nil,
                last_valid_play: nil,
                passes: 0
            }

            {:reply, {:ok, :everyone_passed}, new_state}
          else
            new_state = %{
              state
              | current_player_idx: next_player_idx,
                passes: passes
            }

            {:reply, {:ok, :passed}, new_state}
          end
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
