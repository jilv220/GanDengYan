defmodule GanDengYan do
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

  defp host_game do
    IO.puts("Hosting a new game.")

    # Get player name
    player_name = IO.gets("Enter your name: ") |> String.trim()

    # Start the game server
    {:ok, game_pid} = GanDengYan.GameServer.start_link([])

    # Join as the first player (banker)
    {:ok, _} = GanDengYan.GameServer.join(game_pid, player_name)
    IO.puts("#{player_name} joined as banker. Waiting for other players...")

    # Start a TCP server to accept connections
    {:ok, listen_socket} =
      :gen_tcp.listen(4040, [:binary, packet: :line, active: false, reuseaddr: true])

    IO.puts("Server started on port 4040")

    # Accept connections in a loop
    accept_connections(listen_socket, game_pid)
  end

  defp accept_connections(listen_socket, game_pid) do
    # Accept a client connection
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)

    # Handle client in a separate process
    spawn_link(fn -> handle_client(client_socket, game_pid) end)

    # Give time for client registration to complete
    :timer.sleep(500)

    # Check if we have enough players to start
    game_state = GanDengYan.GameServer.get_state(game_pid)
    player_count = length(game_state.players)

    IO.puts(
      "Current players (#{player_count}): #{Enum.map_join(game_state.players, ", ", & &1.name)}"
    )

    # We need at least 2 players (host + 1 client)
    if player_count >= 2 do
      input = IO.gets("Ready to start the game? (yes/no): ") |> String.trim()

      case input do
        "yes" ->
          case GanDengYan.GameServer.start_game(game_pid) do
            {:ok, _} ->
              IO.puts("Game started!")
              # Notify all clients that game has started
              broadcast_game_start(game_pid)
              # First player is the banker
              banker = List.first(game_state.players)
              play_game(banker.name, game_pid)

            {:error, reason} ->
              IO.puts("Error starting game: #{reason}")
              accept_connections(listen_socket, game_pid)
          end

        _ ->
          accept_connections(listen_socket, game_pid)
      end
    else
      accept_connections(listen_socket, game_pid)
    end
  end

  defp handle_client(socket, game_pid) do
    # Get player name
    :gen_tcp.send(socket, "Enter your name: \n")
    {:ok, data} = :gen_tcp.recv(socket, 0)
    player_name = String.trim(data)

    # Join the game
    case GanDengYan.GameServer.join(game_pid, player_name) do
      {:ok, _} ->
        :gen_tcp.send(socket, "Successfully joined game as #{player_name}\n")
        :gen_tcp.send(socket, "Waiting for host to start the game...\n")

        # Wait for game to start
        wait_for_game_start(socket, game_pid, player_name)

      {:error, reason} ->
        :gen_tcp.send(socket, "Error joining game: #{reason}\n")
        :gen_tcp.close(socket)
    end
  end

  defp wait_for_game_start(socket, game_pid, player_name) do
    game_state = GanDengYan.GameServer.get_state(game_pid)

    if game_state.started do
      :gen_tcp.send(socket, "Game has started!\n")
      client_play_game(socket, game_pid, player_name)
    else
      :timer.sleep(1000)
      wait_for_game_start(socket, game_pid, player_name)
    end
  end

  defp broadcast_game_start(game_pid) do
    # This would notify client connections that the game has started
    # We're handling this implicitly through the wait_for_game_start loop
  end

  defp play_game(player_name, game_pid) do
    game_state = GanDengYan.GameServer.get_state(game_pid)

    # Print current game state
    print_game_state(game_state)

    if game_state.winner do
      IO.puts("Game over! #{game_state.winner} wins!")
      IO.puts("Thanks for playing! Press Ctrl+C to exit.")
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

  defp client_play_game(socket, game_pid, player_name) do
    game_state = GanDengYan.GameServer.get_state(game_pid)

    # Send game state to client
    state_str = format_game_state(game_state)
    :gen_tcp.send(socket, state_str)

    if game_state.winner do
      :gen_tcp.send(socket, "Game over! #{game_state.winner} wins!\n")
      :gen_tcp.send(socket, "Thanks for playing! Press Ctrl+C to exit.\n")
      :gen_tcp.close(socket)
    else
      # Get current player
      current_player = Enum.at(game_state.players, game_state.current_player_idx)

      if current_player.name == player_name do
        handle_client_turn(socket, player_name, game_state, game_pid)
      else
        :gen_tcp.send(socket, "\nWaiting for #{current_player.name} to play...\n")
        :timer.sleep(1000)
        client_play_game(socket, game_pid, player_name)
      end
    end
  end

  defp handle_player_turn(player_name, game_state, game_pid) do
    # Find the player's hand
    player = Enum.find(game_state.players, fn p -> p.name == player_name end)

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

    # Display options
    IO.puts("\nYour cards:")

    sorted_hand
    |> Enum.with_index()
    |> Enum.each(fn {card, idx} ->
      IO.puts("#{idx}: #{Card.to_string(card)}")
    end)

    if is_nil(game_state.last_valid_play) do
      IO.puts("\nYou're first to play! Select cards to play:")
    else
      IO.puts("\nLast played: #{CardPattern.to_string(game_state.last_valid_play)}")
      IO.puts("\nSelect cards to play (or type 'pass' to pass):")
    end

    input = IO.gets("> ") |> String.trim()

    cond do
      input == "pass" and not is_nil(game_state.last_valid_play) ->
        case GanDengYan.GameServer.pass(game_pid, player_name) do
          {:ok, _} ->
            IO.puts("You passed.")
            play_game(player_name, game_pid)

          {:error, reason} ->
            IO.puts("Error: #{reason}")
            handle_player_turn(player_name, game_state, game_pid)
        end

      input == "pass" and is_nil(game_state.last_valid_play) ->
        IO.puts("You cannot pass on the first play.")
        handle_player_turn(player_name, game_state, game_pid)

      true ->
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
            case GanDengYan.GameServer.play_cards(game_pid, player_name, actual_indices) do
              {:ok, :card_played, pattern} ->
                IO.puts("You played: #{CardPattern.to_string(pattern)}")
                play_game(player_name, game_pid)

              {:ok, :game_over, winner} ->
                IO.puts("You played your last cards and won!")
                play_game(player_name, game_pid)

              {:error, reason} ->
                IO.puts("Error: #{reason}")
                handle_player_turn(player_name, game_state, game_pid)
            end
          end
        end
    end
  end

  defp handle_client_turn(socket, player_name, game_state, game_pid) do
    # Find the player's hand
    player = Enum.find(game_state.players, fn p -> p.name == player_name end)

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

    # Display options
    hand_str =
      sorted_hand
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {card, idx} ->
        "#{idx}: #{Card.to_string(card)}"
      end)

    :gen_tcp.send(socket, "\nYour cards:\n#{hand_str}\n")

    prompt =
      if is_nil(game_state.last_valid_play) do
        "\nYou're first to play! Select cards to play:\n> "
      else
        "\nLast played: #{CardPattern.to_string(game_state.last_valid_play)}\n\nSelect cards to play (or type 'pass' to pass):\n> "
      end

    :gen_tcp.send(socket, prompt)

    # Get client input
    {:ok, data} = :gen_tcp.recv(socket, 0)
    input = String.trim(data)

    cond do
      input == "pass" and not is_nil(game_state.last_valid_play) ->
        case GanDengYan.GameServer.pass(game_pid, player_name) do
          {:ok, _} ->
            :gen_tcp.send(socket, "You passed.\n")
            client_play_game(socket, game_pid, player_name)

          {:error, reason} ->
            :gen_tcp.send(socket, "Error: #{reason}\n")
            handle_client_turn(socket, player_name, game_state, game_pid)
        end

      input == "pass" and is_nil(game_state.last_valid_play) ->
        :gen_tcp.send(socket, "You cannot pass on the first play.\n")
        handle_client_turn(socket, player_name, game_state, game_pid)

      true ->
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
          :gen_tcp.send(
            socket,
            "Invalid input. Please enter space-separated indices or 'pass'.\n"
          )

          handle_client_turn(socket, player_name, game_state, game_pid)
        else
          # Map display indices to actual hand indices
          actual_indices = Enum.map(display_indices, fn idx -> Map.get(index_map, idx) end)

          if Enum.any?(actual_indices, &is_nil/1) do
            :gen_tcp.send(socket, "Invalid index. Please use only the numbers shown.\n")
            handle_client_turn(socket, player_name, game_state, game_pid)
          else
            # Try to play the selected cards
            case GanDengYan.GameServer.play_cards(game_pid, player_name, actual_indices) do
              {:ok, :card_played, pattern} ->
                :gen_tcp.send(socket, "You played: #{CardPattern.to_string(pattern)}\n")
                client_play_game(socket, game_pid, player_name)

              {:ok, :game_over, winner} ->
                :gen_tcp.send(socket, "You played your last cards and won!\n")
                client_play_game(socket, game_pid, player_name)

              {:error, reason} ->
                error_msg =
                  case reason do
                    :invalid_pattern ->
                      "Error: The selected cards don't form a valid pattern.\n"

                    :cannot_beat_last_play ->
                      "Error: Your play cannot beat the last play. Try higher cards of same type or a bomb.\n"

                    :invalid_card_indices ->
                      "Error: One or more card indices are invalid.\n"

                    _ ->
                      "Error: #{reason}\n"
                  end

                :gen_tcp.send(socket, error_msg)
                handle_client_turn(socket, player_name, game_state, game_pid)
            end
          end
        end
    end
  end

  defp display_hand_with_indices(hand) do
    # Sort cards by value (high to low) and then by suit
    hand
    |> Enum.sort_by(fn card -> {-Card.value(card), card.suit} end)
    |> Enum.with_index()
    |> Enum.each(fn {card, idx} ->
      IO.puts("#{idx}: #{Card.to_string(card)}")
    end)
  end

  defp format_hand_with_indices(hand) do
    # Sort cards by value (high to low) and then by suit
    hand
    |> Enum.sort_by(fn card -> {-Card.value(card), card.suit} end)
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {card, idx} ->
      "#{idx}: #{Card.to_string(card)}"
    end)
  end

  defp print_game_state(state) do
    IO.puts("\n=== Current Game State ===")

    # Show each player's hand count and banker status
    Enum.each(state.players, fn player ->
      is_current = Enum.at(state.players, state.current_player_idx).name == player.name
      current_marker = if is_current, do: "-> ", else: "   "
      banker_marker = if player.is_banker, do: " (Banker)", else: ""
      IO.puts("#{current_marker}#{player.name}: #{length(player.hand)} cards#{banker_marker}")
    end)

    # Show last play
    if state.last_valid_play do
      IO.puts("\nLast play: #{CardPattern.to_string(state.last_valid_play)}")
    else
      IO.puts("\nNo plays yet")
    end
  end

  defp format_game_state(state) do
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

  defp join_game do
    IO.puts("Joining existing game.")

    # Get connection info
    host = IO.gets("Enter host IP (default: localhost): ") |> String.trim()
    host = if host == "", do: "localhost", else: host

    # Get player name
    player_name = IO.gets("Enter your name: ") |> String.trim()

    # Connect to server
    case :gen_tcp.connect(String.to_charlist(host), 4040, [:binary, packet: :line, active: false]) do
      {:ok, socket} ->
        IO.puts("Connected to game server!")
        # The server will ask for the name
        {:ok, prompt} = :gen_tcp.recv(socket, 0)
        IO.puts(prompt)
        :gen_tcp.send(socket, "#{player_name}\n")

        # Handle the communication loop
        client_loop(socket)

      {:error, reason} ->
        IO.puts("Failed to connect: #{reason}")
        main([])
    end
  end

  defp client_loop(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        IO.write(data)
        # If the server is asking for input, get it from the user
        if String.contains?(data, "Select cards") or
             String.contains?(data, "Enter your name") or
             String.match?(data, ~r/[>\?](\s*)$/) do
          input = IO.gets("")
          :gen_tcp.send(socket, input)
        end

        client_loop(socket)

      {:error, :closed} ->
        IO.puts("Server closed the connection.")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
    end
  end
end
