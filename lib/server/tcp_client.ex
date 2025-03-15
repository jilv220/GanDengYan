defmodule GanDengYan.Server.TCPClient do
  @moduledoc """
  TCP client for connecting to a GanDengYan game server.

  This module handles the TCP connection to the game server.
  """

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
        # Add timeout
        case :gen_tcp.recv(socket, 0, 5000) do
          {:ok, prompt} ->
            # Display the prompt to the user
            IO.write(prompt)
            # Send the player name
            :gen_tcp.send(socket, "#{player_name}\n")
            {:ok, socket}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Main communication loop for the client.

  Reads messages from the server and handles user input.
  """
  @spec client_loop(port(), (String.t() -> :ok)) :: :ok
  def client_loop(socket, display_fn) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        # Display the received data
        display_fn.(data)

        # If the server is asking for input, get it from the user
        if needs_input?(data) do
          input = IO.gets("")
          # Ensure the input has a trailing newline
          input = if String.ends_with?(input, "\n"), do: input, else: input <> "\n"
          :gen_tcp.send(socket, input)
        end

        client_loop(socket, display_fn)

      {:error, :closed} ->
        display_fn.("Server closed the connection.\n")
        :ok

      {:error, reason} ->
        display_fn.("Error: #{reason}\n")
        :ok
    end
  end

  # Helper function to determine if a message is asking for user input
  defp needs_input?(data) do
    String.contains?(data, "Select cards") or
      String.contains?(data, "Enter your name") or
      String.contains?(data, "to play") or
      String.ends_with?(String.trim(data), ">") or
      String.ends_with?(String.trim(data), "?") or
      String.match?(data, ~r/[>\?](\s*)$/)
  end
end
