defmodule GanDengYan.Server.BroadcastManager do
  @moduledoc """
  Manages client connections and broadcasts game events to all clients.

  This module keeps track of active TCP connections and provides functions
  to broadcast messages to all connected clients.
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the broadcast manager.
  """
  def start_link(opts \\ []) do
    Logger.info("Starting BroadcastManager...")
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  @doc """
  Registers a client connection.
  """
  def register_client(socket, player_name) do
    GenServer.cast(__MODULE__, {:register, socket, player_name})
  end

  @doc """
  Unregisters a client connection.
  """
  def unregister_client(socket) do
    GenServer.cast(__MODULE__, {:unregister, socket})
  end

  @doc """
  Broadcasts a message to all connected clients.
  """
  def broadcast(message, except \\ nil) do
    GenServer.cast(__MODULE__, {:broadcast, message, except})
  end

  @doc """
  Sends a message to a specific player.
  """
  def send_to_player(player_name, message) do
    GenServer.cast(__MODULE__, {:send_to_player, player_name, message})
  end

  @doc """
  Broadcasts a game state update to all clients.
  """
  def broadcast_game_state(game_pid, except \\ nil) do
    GenServer.cast(__MODULE__, {:broadcast_game_state, game_pid, except})
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    Logger.info("BroadcastManager initialized")
    {:ok, %{clients: %{}}}
  end

  @impl true
  def handle_cast({:register, socket, player_name}, state) do
    Logger.debug("Registering client: #{player_name}")
    new_clients = Map.put(state.clients, socket, player_name)
    {:noreply, %{state | clients: new_clients}}
  end

  @impl true
  def handle_cast({:unregister, socket}, state) do
    player_name = Map.get(state.clients, socket, "Unknown")
    Logger.debug("Unregistering client: #{player_name}")
    new_clients = Map.delete(state.clients, socket)
    {:noreply, %{state | clients: new_clients}}
  end

  @impl true
  def handle_cast({:broadcast, message, except}, state) do
    Logger.debug("Broadcasting message to #{map_size(state.clients)} clients (except one)")

    Enum.each(state.clients, fn {socket, _} ->
      if socket != except do
        case :gen_tcp.send(socket, message) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to send to socket: #{inspect(reason)}")
            # Consider unregistering this client if sending fails
            unregister_client(socket)
        end
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_to_player, player_name, message}, state) do
    # Find the socket for this player
    socket_entry = Enum.find(state.clients, fn {_, name} -> name == player_name end)

    case socket_entry do
      {socket, _} ->
        case :gen_tcp.send(socket, message) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to send to player #{player_name}: #{inspect(reason)}")
            unregister_client(socket)
        end

      nil ->
        Logger.warning("Player #{player_name} not found")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast_game_state, game_pid, except}, state) do
    case Process.alive?(game_pid) do
      true ->
        # Get current game state
        game_state = GanDengYan.Server.GameServer.get_state(game_pid)
        # Format it for display
        formatted_state = GanDengYan.UI.Formatter.format_game_state(game_state)

        # Send to all clients except the specified one
        Enum.each(state.clients, fn {socket, _} ->
          if socket != except do
            case :gen_tcp.send(socket, formatted_state) do
              :ok ->
                :ok

              {:error, reason} ->
                Logger.error("Failed to broadcast game state: #{inspect(reason)}")
                unregister_client(socket)
            end
          end
        end)

      false ->
        Logger.error("Game process is not alive")
    end

    {:noreply, state}
  end
end
