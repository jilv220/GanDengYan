defmodule GanDengYan.Server.TCPServer do
  @moduledoc """
  TCP server for the GanDengYan game.

  This module handles client connections and dispatches messages to the game server.
  """

  alias GanDengYan.UI.Formatter
  alias GanDengYan.Server.GameServer
  alias GanDengYan.Server.BroadcastManager

  require Logger

  @doc """
  Starts a TCP server on the specified port.

  Returns {:ok, listen_socket} on success, or {:error, reason} on failure.
  """
  @spec start(integer(), pid()) :: {:ok, port(), pid()} | {:error, any()}
  def start(port \\ 4040, game_pid) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        Logger.info("Server started on port #{port}")
        {:ok, listen_socket, game_pid}

      {:error, reason} ->
        Logger.error("Failed to start server: #{inspect(reason)}")
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
        Logger.info("New client connection accepted")

        # Handle client in a separate process
        spawn_link(fn -> handle_client(client_socket, game_pid) end)

        # Continue accepting connections
        accept_connections(listen_socket, game_pid)

      {:error, reason} ->
        Logger.error("Error accepting connection: #{inspect(reason)}")
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
        Logger.info("Player #{player_name} trying to join")

        # Join the game
        case GameServer.join(game_pid, player_name) do
          {:ok, _} ->
            Logger.info("Player #{player_name} joined successfully")

            # Register this client with the broadcast manager
            BroadcastManager.register_client(socket, player_name)

            # Notify the client
            :gen_tcp.send(socket, "Successfully joined game as #{player_name}\n")
            :gen_tcp.send(socket, "Waiting for host to start the game...\n")

            # Notify all other clients about the new player
            player_joined_msg = "\n#{player_name} has joined the game.\n"
            BroadcastManager.broadcast(player_joined_msg, socket)

            # Enter the client loop
            client_loop(socket, game_pid, player_name)

          {:error, reason} ->
            error_msg = error_message(reason)
            Logger.warning("Player #{player_name} failed to join: #{error_msg}")
            :gen_tcp.send(socket, "Error joining game: #{error_msg}\n")
            # Give the client a chance to read the error
            :timer.sleep(3000)
            :gen_tcp.close(socket)
        end

      {:error, reason} ->
        Logger.error("Error receiving player name: #{inspect(reason)}")
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
      # Check if the socket is still open with a short timeout
      case :gen_tcp.recv(socket, 0, 1000) do
        {:ok, _data} ->
          # Unexpected data received, ignore it
          client_loop(socket, game_pid, player_name)

        {:error, :timeout} ->
          # This is expected, just keep looping
          client_loop(socket, game_pid, player_name)

        {:error, reason} ->
          Logger.info("Client disconnected: #{player_name}, reason: #{inspect(reason)}")
          # Socket closed, unregister the client
          BroadcastManager.unregister_client(socket)
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

    case :gen_tcp.send(socket, state_str) do
      :ok ->
        :ok

      {:error, _reason} ->
        # If we can't send to the socket, assume client disconnected
        handle_client_disconnect(socket, game_pid, player_name)
        exit(:normal)
    end

    if game_state.winner do
      # Game over
      :gen_tcp.send(socket, "Game over! #{game_state.winner} wins!\n")
      :gen_tcp.send(socket, "Thanks for playing! Press Ctrl+C to exit.\n")

      # Give client some time to display the message before closing
      :timer.sleep(5000)
      :gen_tcp.close(socket)
    else
      # Get current player
      current_player = Enum.at(game_state.players, game_state.current_player_idx)

      if current_player && current_player.name == player_name do
        # It's this player's turn
        handle_player_turn(socket, player_name, game_state, game_pid)
      else
        # Not this player's turn - wait for updates or periodic refresh
        wait_for_turn(socket, game_pid, player_name, current_player)
      end
    end
  end

  # Wait for turn or updates using a more reliable approach
  defp wait_for_turn(socket, game_pid, player_name, current_player) do
    current_name = if current_player, do: current_player.name, else: "Unknown"

    # Tell the player we're waiting for another player's move
    case :gen_tcp.send(socket, "\nWaiting for #{current_name} to play...\n") do
      :ok ->
        :ok

      {:error, _reason} ->
        handle_client_disconnect(socket, game_pid, player_name)
        exit(:normal)
    end

    # Wait for a while then refresh
    :timer.sleep(3000)
    handle_game_play(socket, game_pid, player_name)
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

    # Send player's cards
    case :gen_tcp.send(socket, "\nYour cards:\n#{hand_display}\n") do
      :ok ->
        :ok

      {:error, _reason} ->
        handle_client_disconnect(socket, game_pid, player_name)
        exit(:normal)
    end

    # Get prompt based on game state
    prompt = Formatter.format_play_prompt(game_state)

    # Send prompt
    case :gen_tcp.send(socket, prompt) do
      :ok ->
        :ok

      {:error, _reason} ->
        handle_client_disconnect(socket, game_pid, player_name)
        exit(:normal)
    end

    # Get client input with a longer timeout (2 minutes)
    case :gen_tcp.recv(socket, 0, 120_000) do
      {:ok, data} ->
        input = String.trim(data)

        try do
          handle_player_input(socket, player_name, game_state, game_pid, input, index_map)
        catch
          kind, error ->
            Logger.error("Error handling player input: #{inspect(kind)}, #{inspect(error)}")
            stacktrace = Process.info(self(), :current_stacktrace)
            Logger.error("Stacktrace: #{inspect(stacktrace)}")
            # Try to recover and continue
            handle_game_play(socket, game_pid, player_name)
        end

      {:error, :timeout} ->
        # Player took too long, notify and prompt again
        :gen_tcp.send(socket, "Time is running out! Please make a move.\n")
        handle_player_turn(socket, player_name, game_state, game_pid)

      {:error, reason} ->
        Logger.error("Error receiving player input: #{inspect(reason)}")
        handle_client_disconnect(socket, game_pid, player_name)
        exit(:normal)
    end
  end

  @doc """
  Processes a player's input when they choose to pass.
  """
  @spec handle_player_input(port(), String.t(), map(), pid(), String.t(), map()) :: no_return()
  def handle_player_input(
        socket,
        player_name,
        %{last_valid_play: nil} = game_state,
        game_pid,
        "pass",
        _
      ) do
    :gen_tcp.send(socket, "You cannot pass on the first play.\n")
    handle_player_turn(socket, player_name, game_state, game_pid)
  end

  def handle_player_input(socket, player_name, game_state, game_pid, "pass", _) do
    case GameServer.pass(game_pid, player_name) do
      {:ok, :everyone_passed, last_player_idx} ->
        handle_everyone_passed(socket, player_name, game_state, game_pid, last_player_idx)

      {:ok, :passed} ->
        :gen_tcp.send(socket, "You passed.\n")

        # Broadcast to other players
        pass_message = "\n#{player_name} passed.\n"
        BroadcastManager.broadcast(pass_message, socket)

        # Broadcast updated game state
        BroadcastManager.broadcast_game_state(game_pid, socket)

        handle_game_play(socket, game_pid, player_name)

      {:error, reason} ->
        :gen_tcp.send(socket, "Error: #{error_message(reason)}\n")
        handle_player_turn(socket, player_name, game_state, game_pid)
    end
  end

  def handle_player_input(socket, player_name, game_state, game_pid, input, index_map) do
    with {:ok, indices} <- parse_indices(input),
         {:ok, actual_indices} <- validate_indices(indices, index_map) do
      case GameServer.play_cards(game_pid, player_name, actual_indices) do
        {:ok, :card_played, pattern} ->
          :gen_tcp.send(socket, "You played: #{Formatter.format_pattern(pattern)}\n")

          # Broadcast to other players
          play_message = "\n#{player_name} played: #{Formatter.format_pattern(pattern)}\n"
          BroadcastManager.broadcast(play_message, socket)

          # Broadcast updated game state
          BroadcastManager.broadcast_game_state(game_pid, socket)

          handle_game_play(socket, game_pid, player_name)

        {:ok, :game_over, winner} ->
          :gen_tcp.send(socket, "You played your last cards and won!\n")

          # Broadcast game over
          game_over_message = "\nGame over! #{winner} has won the game!\n"
          BroadcastManager.broadcast(game_over_message, nil)
          BroadcastManager.broadcast_game_state(game_pid, socket)

          handle_game_play(socket, game_pid, player_name)

        {:error, reason} ->
          :gen_tcp.send(socket, "Error: #{error_message(reason)}\n")
          handle_player_turn(socket, player_name, game_state, game_pid)
      end
    else
      {:error, :empty_selection} ->
        :gen_tcp.send(socket, "Invalid input. Please enter space-separated indices or 'pass'.\n")
        handle_player_turn(socket, player_name, game_state, game_pid)

      {:error, :invalid_index} ->
        :gen_tcp.send(socket, "Invalid index. Please use only the numbers shown.\n")
        handle_player_turn(socket, player_name, game_state, game_pid)
    end
  end

  # Helper functions

  defp handle_everyone_passed(socket, player_name, game_state, game_pid, last_player_idx) do
    last_player = Enum.at(game_state.players, last_player_idx)

    message =
      if player_name == last_player.name do
        "\n*** Everyone passed on your play! You get to draw a card and play again! ***\n" <>
          "A card has been added to your hand.\n"
      else
        "Everyone passed! #{last_player.name} gets to draw a card and play again.\n"
      end

    :gen_tcp.send(socket, message)

    # Broadcast to others
    pass_message =
      "\n#{player_name} passed - everyone has passed. #{last_player.name} goes again.\n"

    BroadcastManager.broadcast(pass_message, socket)

    # Broadcast updated game state
    BroadcastManager.broadcast_game_state(game_pid, socket)

    handle_game_play(socket, game_pid, player_name)
  end

  defp parse_indices(input) do
    indices =
      try do
        input
        |> String.split(" ", trim: true)
        |> Enum.map(&String.to_integer/1)
      rescue
        _ -> []
      end

    if Enum.empty?(indices), do: {:error, :empty_selection}, else: {:ok, indices}
  end

  defp validate_indices(indices, index_map) do
    actual_indices = Enum.map(indices, &Map.get(index_map, &1))

    if Enum.any?(actual_indices, &is_nil/1) do
      {:error, :invalid_index}
    else
      {:ok, actual_indices}
    end
  end

  defp handle_client_disconnect(socket, _game_pid, player_name) do
    Logger.info("Handling disconnect for player: #{player_name}")
    BroadcastManager.unregister_client(socket)
    # Not actually disconnected - don't mark as such in game server
    :gen_tcp.close(socket)
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

      :cannot_pass_first_play ->
        "You cannot pass on the first play."

      _ ->
        to_string(reason)
    end
  end
end
