defmodule GanDengYan.Server.TCPClient do
  @moduledoc """
  TCP client for connecting to a GanDengYan game server.

  This module handles the TCP connection to the game server.
  """

  require Logger

  @doc """
  Connects to a game server at the specified host and port.

  Returns {:ok, socket} on success, or {:error, reason} on failure.
  """
  @spec connect(String.t(), integer(), String.t()) :: {:ok, port()} | {:error, any()}
  def connect(host, port, player_name) do
    opts = [:binary, packet: :line, active: false]

    case :gen_tcp.connect(String.to_charlist(host), port, opts) do
      {:ok, socket} ->
        # Read the name prompt
        case :gen_tcp.recv(socket, 0, 5000) do
          {:ok, prompt} ->
            # Display the prompt to the user
            IO.write(prompt)

            # Send the player name
            :gen_tcp.send(socket, "#{player_name}\n")
            {:ok, socket}

          {:error, reason} ->
            Logger.error("Error receiving prompt: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Connection error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Main communication loop for the client.

  Uses active mode for sockets to receive messages as they arrive.
  """
  @spec client_loop(port(), (String.t() -> :ok)) :: :ok
  def client_loop(socket, display_fn) do
    # Create a separate process for reading user input
    input_pid = spawn_link(fn -> input_reader(socket) end)

    # Set socket to active mode, to receive messages as they arrive
    :inet.setopts(socket, active: true)

    # Main loop in this process handles socket messages
    receive_loop(socket, display_fn, input_pid)
  end

  # Process that continuously reads user input
  defp input_reader(socket) do
    input = IO.gets("")

    # Only send if non-empty
    if input && input != "" do
      # Ensure it ends with newline
      input = if String.ends_with?(input, "\n"), do: input, else: input <> "\n"
      :gen_tcp.send(socket, input)
    end

    # Continue reading input
    input_reader(socket)
  end

  # Main receive loop handles socket messages
  defp receive_loop(socket, display_fn, input_pid) do
    receive do
      {:tcp, ^socket, data} ->
        # Display received data
        display_fn.(data)
        receive_loop(socket, display_fn, input_pid)

      {:tcp_closed, ^socket} ->
        display_fn.("Server closed the connection.\n")
        Process.exit(input_pid, :kill)
        :ok

      {:tcp_error, ^socket, reason} ->
        display_fn.("Error: #{inspect(reason)}\n")
        Process.exit(input_pid, :kill)
        :ok
    end
  end
end
