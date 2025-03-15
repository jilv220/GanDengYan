defmodule GanDengYan.Server.GameServer do
  @moduledoc """
  GenServer implementation for managing a GanDengYan game.

  This server maintains the game state and handles all game-related operations.
  """

  use GenServer
  alias GanDengYan.Game.GameState

  # Client API

  @doc """
  Starts a new game server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Adds a player to the game.
  """
  @spec join(GenServer.server(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def join(server, player_name) do
    GenServer.call(server, {:join, player_name})
  end

  @doc """
  Starts the game.
  """
  @spec start_game(GenServer.server()) ::
          {:ok, map()} | {:error, atom()}
  def start_game(server) do
    GenServer.call(server, :start_game)
  end

  @doc """
  Plays cards from a player's hand.
  """
  @spec play_cards(GenServer.server(), String.t(), [non_neg_integer()]) ::
          {:ok, atom(), term()} | {:error, atom()}
  def play_cards(server, player_name, card_indices) do
    GenServer.call(server, {:play_cards, player_name, card_indices})
  end

  @doc """
  Passes a turn.
  """
  @spec pass(GenServer.server(), String.t()) ::
          {:ok, atom()} | {:ok, atom(), non_neg_integer()} | {:error, atom()}
  def pass(server, player_name) do
    GenServer.call(server, {:pass, player_name})
  end

  @doc """
  Gets the current game state.
  """
  @spec get_state(GenServer.server()) :: map()
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    {:ok, GameState.new()}
  end

  @impl true
  def handle_call({:join, player_name}, _from, state) do
    case GameState.add_player(state, player_name) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:start_game, _from, state) do
    case GameState.start_game(state) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:play_cards, player_name, card_indices}, _from, state) do
    case GameState.play_cards(state, player_name, card_indices) do
      {:ok, :card_played, pattern, new_state} ->
        {:reply, {:ok, :card_played, pattern}, new_state}

      {:ok, :game_over, winner, new_state} ->
        {:reply, {:ok, :game_over, winner}, new_state}

      {:error, reason, _} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:pass, player_name}, _from, state) do
    case GameState.pass(state, player_name) do
      {:ok, :passed, new_state} ->
        {:reply, {:ok, :passed}, new_state}

      {:ok, :everyone_passed, last_player_idx, new_state} ->
        {:reply, {:ok, :everyone_passed, last_player_idx}, new_state}

      {:error, reason, _} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
