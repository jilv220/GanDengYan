defmodule GanDengYan.Server.TCPServer do
  @moduledoc """
  TCP server for the GanDengYan game.

  This module handles client connections and dispatches messages to the game server.
  """

  alias GanDengYan.UI.Formatter
  alias GanDengYan.Server.GameServer

  @doc """
  Starts a TCP server on the specified port.

  Returns {:ok, listen_socket} on success, or {:error, reason} on failure.
  """
  @spec start(integer(), pid()) :: {:ok, port()} | {:error, any()}
  def start(port \\ 4040, game_pid) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        IO.puts("Server started on port #{port}")
        {:ok, listen_socket, game_pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Accepts connections and spawns handlers for each client.
  """
  @spec accept_connections(port(), pid()) :: no_return()
  def accept_connections(listen_socket, game_pid) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        # Set socket options
        :ok = :inet.setopts(client_socket, [{:keepalive, true}])

        # Handle client in a separate process
        spawn_link(fn -> handle_client(client_socket, game_pid) end)

        # Continue accepting connections
        accept_connections(listen_socket, game_pid)

      {:error, reason} ->
        IO.puts("Error accepting connection: #{reason}")
        # Try again after a short delay
        :timer.sleep(1000)
        accept_connections(listen_socket, game_pid)
    end
  end

  @doc """
  Handles client connection and communication.
  """
  @spec handle_client(port(), pid()) :: no_return()
  def handle_client(socket, game_pid) do
    # Get player name
    :gen_tcp.send(socket, "Enter your name: \n")

    # Longer timeout for slow typing
    case :gen_tcp.recv(socket, 0, 30000) do
      {:ok, data} ->
        player_name = String.trim(data)

        # Join the game
        case GameServer.join(game_pid, player_name) do
          {:ok, _} ->
            # Register this client with the broadcast manager
            GanDengYan.Server.BroadcastManager.register_client(socket, player_name)

            # Notify the client
            :gen_tcp.send(socket, "Successfully joined game as #{player_name}\n")
            :gen_tcp.send(socket, "Waiting for host to start the game...\n")

            # Notify all other clients about the new player
            player_joined_msg = "\n#{player_name} has joined the game.\n"
            GanDengYan.Server.BroadcastManager.broadcast(player_joined_msg, socket)

            # Enter the client loop
            client_loop(socket, game_pid, player_name)

          {:error, reason} ->
            error_msg = error_message(reason)
            :gen_tcp.send(socket, "Error joining game: #{error_msg}\n")
            # Give the client a chance to read the error
            :timer.sleep(3000)
            :gen_tcp.close(socket)
        end

      {:error, reason} ->
        IO.puts("Error receiving data: #{reason}")
        :gen_tcp.close(socket)
    end
  end

  @doc """
  Main client communication loop.

  Waits for the game to start and then handles playing the game.
  """
  @spec client_loop(port(), pid(), String.t()) :: no_return()
  def client_loop(socket, game_pid, player_name) do
    game_state = GameServer.get_state(game_pid)

    if game_state.started do
      handle_game_play(socket, game_pid, player_name)
    else
      # Check if the socket is still open
      case :gen_tcp.recv(socket, 0, 1000) do
        {:ok, _data} ->
          # Unexpected data received, ignore it
          client_loop(socket, game_pid, player_name)

        {:error, :timeout} ->
          # This is expected, just keep looping
          client_loop(socket, game_pid, player_name)

        {:error, _reason} ->
          # Socket closed, unregister the client
          GanDengYan.Server.BroadcastManager.unregister_client(socket)
          :gen_tcp.close(socket)
      end
    end
  end

  @doc """
  Handles game play for the client once the game has started.
  """
  @spec handle_game_play(port(), pid(), String.t()) :: no_return()
  def handle_game_play(socket, game_pid, player_name) do
    game_state = GameServer.get_state(game_pid)

    # Send game state to client
    state_str = Formatter.format_game_state(game_state)
    :gen_tcp.send(socket, state_str)

    if game_state.winner do
      # Game over
      :gen_tcp.send(socket, "Game over! #{game_state.winner} wins!\n")
      :gen_tcp.send(socket, "Thanks for playing! Press Ctrl+C to exit.\n")
      :gen_tcp.close(socket)
    else
      # Get current player
      current_player = Enum.at(game_state.players, game_state.current_player_idx)

      if current_player.name == player_name do
        # It's this player's turn
        handle_player_turn(socket, player_name, game_state, game_pid)
      else
        # Not this player's turn
        :gen_tcp.send(socket, "\nWaiting for #{current_player.name} to play...\n")
        :timer.sleep(1000)
        handle_game_play(socket, game_pid, player_name)
      end
    end
  end

  @doc """
  Handles input from a player during their turn.
  """
  @spec handle_player_turn(port(), String.t(), map(), pid()) :: no_return()
  def handle_player_turn(socket, player_name, game_state, game_pid) do
    # Find the player
    player = Enum.find(game_state.players, fn p -> p.name == player_name end)

    # Get indexed hand display and mapping
    {hand_display, index_map} = Formatter.format_hand_for_selection(player)
    :gen_tcp.send(socket, "\nYour cards:\n#{hand_display}\n")

    # Get prompt based on game state
    prompt = Formatter.format_play_prompt(game_state)
    :gen_tcp.send(socket, prompt)

    # Get client input
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        input = String.trim(data)
        handle_player_input(socket, player_name, game_state, game_pid, input, index_map)

      {:error, reason} ->
        IO.puts("Error receiving data: #{reason}")
        :gen_tcp.close(socket)
    end
  end

  @doc """
  Processes a player's input during their turn.
  """
  @spec handle_player_input(port(), String.t(), map(), pid(), String.t(), map()) :: no_return()
  def handle_player_input(socket, player_name, game_state, game_pid, "pass", _) do
    if is_nil(game_state.last_valid_play) do
      :gen_tcp.send(socket, "You cannot pass on the first play.\n")
      handle_player_turn(socket, player_name, game_state, game_pid)
    else
      case GameServer.pass(game_pid, player_name) do
        {:ok, :everyone_passed, last_player_idx} ->
          last_player = Enum.at(game_state.players, last_player_idx)

          message =
            if player_name == last_player.name do
              "\n*** Everyone passed on your play! You get to draw a card and play again! ***\n" <>
                "A card has been added to your hand.\n"
            else
              "Everyone passed! #{last_player.name} gets to draw a card and play again.\n"
            end

          :gen_tcp.send(socket, message)
          handle_game_play(socket, game_pid, player_name)

        {:ok, :passed} ->
          :gen_tcp.send(socket, "You passed.\n")
          handle_game_play(socket, game_pid, player_name)

        {:error, reason} ->
          :gen_tcp.send(socket, "Error: #{error_message(reason)}\n")
          handle_player_turn(socket, player_name, game_state, game_pid)
      end
    end
  end

  def handle_player_input(socket, player_name, game_state, game_pid, input, index_map) do
    # Parse indices
    display_indices =
      try do
        input
        |> String.split(" ", trim: true)
        |> Enum.map(&String.to_integer/1)
      rescue
        _ -> []
      end

    if Enum.empty?(display_indices) do
      :gen_tcp.send(socket, "Invalid input. Please enter space-separated indices or 'pass'.\n")
      handle_player_turn(socket, player_name, game_state, game_pid)
    else
      # Map display indices to actual hand indices
      actual_indices = Enum.map(display_indices, fn idx -> Map.get(index_map, idx) end)

      if Enum.any?(actual_indices, &is_nil/1) do
        :gen_tcp.send(socket, "Invalid index. Please use only the numbers shown.\n")
        handle_player_turn(socket, player_name, game_state, game_pid)
      else
        # Try to play the selected cards
        case GameServer.play_cards(game_pid, player_name, actual_indices) do
          {:ok, :card_played, pattern} ->
            :gen_tcp.send(socket, "You played: #{Formatter.format_pattern(pattern)}\n")
            handle_game_play(socket, game_pid, player_name)

          {:ok, :game_over, winner} ->
            :gen_tcp.send(socket, "You played your last cards and won!\n")
            handle_game_play(socket, game_pid, player_name)

          {:error, reason} ->
            :gen_tcp.send(socket, "Error: #{error_message(reason)}\n")
            handle_player_turn(socket, player_name, game_state, game_pid)
        end
      end
    end
  end

  # Helper function to convert error atoms to human-readable messages
  defp error_message(reason) do
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

      _ ->
        to_string(reason)
    end
  end
end
