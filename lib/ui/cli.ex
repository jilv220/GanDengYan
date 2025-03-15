defmodule GanDengYan.UI.CLI do
  @moduledoc """
  Command-line interface for the GanDengYan game.

  This module handles user input and display for the CLI version of the game.
  """

  alias GanDengYan.Server.{GameServer, TCPServer}
  alias GanDengYan.UI.Formatter

  @doc """
  Main entry point for the CLI application.
  """
  @spec main([String.t()]) :: :ok
  def main(_args) do
    IO.puts("Welcome to GanDengYan card game!")

    # Prompt for hosting or joining a game
    action = IO.gets("Create a new game or join existing? (create/join): ") |> String.trim()

    case action do
      "create" ->
        host_game()

      "join" ->
        join_game()

      _ ->
        IO.puts("Invalid option. Please choose 'create' or 'join'.")
        main([])
    end
  end

  @doc """
  Hosts a new game.
  """
  @spec host_game() :: :ok
  def host_game do
    IO.puts("Hosting a new game.")

    # Get player name
    player_name = IO.gets("Enter your name: ") |> String.trim()

    # Start the game server
    {:ok, game_pid} = GameServer.start_link([])

    # Join as the first player (banker)
    {:ok, _} = GameServer.join(game_pid, player_name)
    IO.puts("#{player_name} joined as banker. Waiting for other players...")

    # Start a TCP server
    case TCPServer.start(4040, game_pid) do
      {:ok, listen_socket, _} ->
        IO.puts("Server started on port 4040")
        accept_connections(listen_socket, game_pid, player_name)

      {:error, reason} ->
        IO.puts("Error starting server: #{reason}")
        :ok
    end
  end

  @doc """
  Accepts client connections.
  """
  @spec accept_connections(port(), pid(), String.t()) :: :ok
  def accept_connections(listen_socket, game_pid, player_name) do
    # Accept a client connection
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        # Handle client in a separate process
        spawn_link(fn -> TCPServer.handle_client(client_socket, game_pid) end)

        # Give time for client registration to complete
        :timer.sleep(500)

        # Check if we have enough players to start
        game_state = GameServer.get_state(game_pid)
        player_count = length(game_state.players)

        IO.puts(
          "Current players (#{player_count}): #{Enum.map_join(game_state.players, ", ", & &1.name)}"
        )

        # We need at least 2 players (host + 1 client)
        if player_count >= 2 do
          input = IO.gets("Ready to start the game? (yes/no): ") |> String.trim()

          case input do
            "yes" ->
              case GameServer.start_game(game_pid) do
                {:ok, _} ->
                  IO.puts("Game started!")
                  play_game(player_name, game_pid)

                {:error, reason} ->
                  IO.puts("Error starting game: #{Formatter.format_error(reason)}")
                  accept_connections(listen_socket, game_pid, player_name)
              end

            _ ->
              accept_connections(listen_socket, game_pid, player_name)
          end
        else
          accept_connections(listen_socket, game_pid, player_name)
        end

      {:error, reason} ->
        IO.puts("Error accepting connection: #{reason}")
        # Try again
        accept_connections(listen_socket, game_pid, player_name)
    end
  end

  @doc """
  Main game loop for the host player.
  """
  @spec play_game(String.t(), pid()) :: :ok
  def play_game(player_name, game_pid) do
    game_state = GameServer.get_state(game_pid)

    # Print current game state
    IO.puts(Formatter.format_game_state(game_state))

    if game_state.winner do
      IO.puts("Game over! #{game_state.winner} wins!")
      IO.puts("Thanks for playing! Press Ctrl+C to exit.")
      :ok
    else
      # Get current player
      current_player = Enum.at(game_state.players, game_state.current_player_idx)

      if current_player.name == player_name do
        IO.puts("\nIt's your turn!")
        handle_player_turn(player_name, game_state, game_pid)
      else
        IO.puts("\nWaiting for #{current_player.name} to play...")
        :timer.sleep(1000)
        play_game(player_name, game_pid)
      end
    end
  end

  @doc """
  Handles input during a player's turn.
  """
  @spec handle_player_turn(String.t(), map(), pid()) :: :ok
  def handle_player_turn(player_name, game_state, game_pid) do
    # Find the player
    player = Enum.find(game_state.players, fn p -> p.name == player_name end)

    # Get indexed hand display and mapping
    {hand_display, index_map} = Formatter.format_hand_for_selection(player)
    IO.puts("\nYour cards:")
    IO.puts(hand_display)

    # Get input based on game state
    input =
      if is_nil(game_state.last_valid_play) do
        IO.puts("\nYou're first to play! Select cards to play:")
        IO.gets("> ") |> String.trim()
      else
        IO.puts("\nLast played: #{Formatter.format_pattern(game_state.last_valid_play)}")
        IO.puts("\nSelect cards to play (or type 'pass' to pass):")
        IO.gets("> ") |> String.trim()
      end

    # Handle input
    handle_player_input(player_name, game_state, game_pid, input, index_map)
  end

  @doc """
  Processes a player's input during their turn.
  """
  @spec handle_player_input(String.t(), map(), pid(), String.t(), map()) :: :ok
  def handle_player_input(player_name, game_state, game_pid, "pass", _) do
    if is_nil(game_state.last_valid_play) do
      IO.puts("You cannot pass on the first play.")
      handle_player_turn(player_name, game_state, game_pid)
    else
      case GameServer.pass(game_pid, player_name) do
        {:ok, :everyone_passed, last_player_idx} ->
          last_player = Enum.at(game_state.players, last_player_idx)

          if player_name == last_player.name do
            IO.puts(
              "\n*** Everyone passed on your play! You get to draw a card and play again! ***"
            )

            IO.puts("A card has been added to your hand.")
          else
            IO.puts("Everyone passed! #{last_player.name} gets to draw a card and play again.")
          end

          play_game(player_name, game_pid)

        {:ok, :passed} ->
          IO.puts("You passed.")
          play_game(player_name, game_pid)

        {:error, reason} ->
          IO.puts("Error: #{Formatter.format_error(reason)}")
          handle_player_turn(player_name, game_state, game_pid)
      end
    end
  end

  def handle_player_input(player_name, game_state, game_pid, input, index_map) do
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
      IO.puts("Invalid input. Please enter space-separated indices or 'pass'.")
      handle_player_turn(player_name, game_state, game_pid)
    else
      # Map display indices to actual hand indices
      actual_indices = Enum.map(display_indices, fn idx -> Map.get(index_map, idx) end)

      if Enum.any?(actual_indices, &is_nil/1) do
        IO.puts("Invalid index. Please use only the numbers shown.")
        handle_player_turn(player_name, game_state, game_pid)
      else
        # Try to play the selected cards
        case GameServer.play_cards(game_pid, player_name, actual_indices) do
          {:ok, :card_played, pattern} ->
            IO.puts("You played: #{Formatter.format_pattern(pattern)}")
            play_game(player_name, game_pid)

          {:ok, :game_over, winner} ->
            IO.puts("You played your last cards and won!")
            play_game(player_name, game_pid)

          {:error, reason} ->
            IO.puts("Error: #{Formatter.format_error(reason)}")
            handle_player_turn(player_name, game_state, game_pid)
        end
      end
    end
  end

  @doc """
  Joins an existing game.
  """
  @spec join_game() :: :ok
  def join_game do
    IO.puts("Joining existing game.")

    # Get connection info
    host = IO.gets("Enter host IP (default: localhost): ") |> String.trim()
    host = if host == "", do: "localhost", else: host

    # Get player name
    player_name = IO.gets("Enter your name: ") |> String.trim()

    # Connect to server using our TCPClient
    IO.puts("Connecting to #{host}:4040...")

    # Using standard connect for simplicity here
    case :gen_tcp.connect(String.to_charlist(host), 4040, [:binary, packet: :line, active: false]) do
      {:ok, socket} ->
        IO.puts("Connected to game server!")

        # Use our client loop function with a display function for IO
        display_fn = fn msg -> IO.write(msg) end
        GanDengYan.Server.TCPClient.client_loop(socket, display_fn)

      {:error, reason} ->
        IO.puts("Failed to connect: #{reason}")
        main([])
    end
  end
end
