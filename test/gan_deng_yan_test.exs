defmodule GanDengYanTest do
  use ExUnit.Case

  # You can update this test to check something meaningful in your app
  # For example:
  test "deck creation works correctly" do
    deck = GanDengYan.Game.Deck.new()
    # 52 cards + 2 jokers
    assert length(deck) == 54
  end

  # Add more tests for your actual implementation
end
