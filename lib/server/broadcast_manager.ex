defmodule GanDengYan.Server.BroadcastManager do
  @moduledoc """
  Manages client connections and broadcasts game events to all clients.

  This module keeps track of active TCP connections and provides functions
  to broadcast messages to all connected clients.
  """

  use GenServer

  # Client API

  @doc """
  Starts the broadcast manager.
  """
  def start_link(opts \\ []) do
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

  # Server callbacks

  @impl true
  def init(:ok) do
    {:ok, %{clients: %{}}}
  end

  @impl true
  def handle_cast({:register, socket, player_name}, state) do
    new_clients = Map.put(state.clients, socket, player_name)
    {:noreply, %{state | clients: new_clients}}
  end

  @impl true
  def handle_cast({:unregister, socket}, state) do
    new_clients = Map.delete(state.clients, socket)
    {:noreply, %{state | clients: new_clients}}
  end

  @impl true
  def handle_cast({:broadcast, message, except}, state) do
    Enum.each(state.clients, fn {socket, _} ->
      if socket != except do
        :gen_tcp.send(socket, message)
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_to_player, player_name, message}, state) do
    # Find the socket for this player
    {socket, _} = Enum.find(state.clients, {nil, nil}, fn {_, name} -> name == player_name end)

    if socket do
      :gen_tcp.send(socket, message)
    end

    {:noreply, state}
  end
end
