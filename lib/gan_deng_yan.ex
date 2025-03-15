defmodule GanDengYan do
  @moduledoc """
  The main module for the GanDengYan card game.

  GanDengYan is a Chinese card game similar to Big Two or Tycoon.
  Players take turns playing card patterns, trying to be the first
  to play all their cards.
  """

  alias GanDengYan.UI.CLI
  alias GanDengYan.Server.BroadcastManager

  @doc """
  Entry point for the application when running as an escript.
  """
  @spec main([String.t()]) :: :ok
  def main(args) do
    # Start the broadcast manager for client communication
    {:ok, _} = BroadcastManager.start_link()

    # Start the CLI interface
    CLI.main(args)
  end
end
