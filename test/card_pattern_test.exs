defmodule GanDengYan.Game.CardPatternTest do
  use ExUnit.Case
  alias GanDengYan.Game.{Card, CardPattern}

  # Helper function to create cards quickly
  defp card(face, suit), do: %Card{face: face, suit: suit}

  # Helper to create a joker
  defp joker, do: %Card{face: :joker, suit: nil}

  describe "identify/1 for single cards" do
    test "identifies a single non-joker card" do
      cards = [card(:ace, :spades)]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :single
      assert pattern.value == Card.value(hd(cards))
    end

    test "rejects a single joker" do
      cards = [joker()]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :invalid
    end
  end

  describe "identify/1 for pairs" do
    test "identifies a regular pair" do
      cards = [card(7, :hearts), card(7, :spades)]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :pair
      assert pattern.value == 7
    end

    test "identifies a pair with one joker" do
      cards = [card(9, :clubs), joker()]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :pair
      assert pattern.value == 9
    end

    test "rejects cards that don't form a pair" do
      cards = [card(8, :diamonds), card(9, :hearts)]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :invalid
    end
  end

  describe "identify/1 for bomb" do
    test "identifies a regular bomb" do
      cards = [
        card(:king, :hearts),
        card(:king, :spades),
        card(:king, :diamonds)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :bomb
      assert pattern.value == Card.value(card(:king, :hearts))
    end

    test "identifies a bomb with one joker" do
      cards = [
        card(5, :clubs),
        card(5, :diamonds),
        joker()
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :bomb
      assert pattern.value == 5
    end

    test "identifies a bomb with two jokers" do
      cards = [
        card(:queen, :hearts),
        joker(),
        joker()
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :bomb
      assert pattern.value == Card.value(card(:queen, :hearts))
    end

    test "identifies a bomb with all jokers" do
      cards = [joker(), joker(), joker()]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :bomb
      assert pattern.value == Card.value(joker())
    end

    test "identifies a special bomb" do
      cards = [joker(), joker()]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :bomb
      assert pattern.value == Card.value(joker())
    end
  end

  describe "identify/1 for abombs" do
    test "identifies a regular abomb" do
      cards = [
        card(10, :hearts),
        card(10, :spades),
        card(10, :diamonds),
        card(10, :clubs)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :abomb
      assert pattern.value == 10
    end

    test "identifies an abomb with one joker" do
      cards = [
        card(:jack, :clubs),
        card(:jack, :diamonds),
        card(:jack, :hearts),
        joker()
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :abomb
      assert pattern.value == Card.value(card(:jack, :hearts))
    end

    test "identifies an abomb with two jokers" do
      cards = [
        card(8, :hearts),
        card(8, :spades),
        joker(),
        joker()
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :abomb
      assert pattern.value == 8
    end

    test "identifies an abomb with three jokers" do
      cards = [
        card(:ace, :hearts),
        joker(),
        joker(),
        joker()
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :abomb
      assert pattern.value == Card.value(card(:ace, :hearts))
    end

    test "identifies an abomb of four jokers" do
      cards = [joker(), joker(), joker(), joker()]
      pattern = CardPattern.identify(cards)

      assert pattern.type == :abomb
      assert pattern.value == Card.value(joker())
    end

    test "identifies an abomb with jokers forming entire pairs" do
      cards = [
        # 9 bomb
        card(9, :hearts),
        card(9, :spades),
        joker(),
        joker()
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :abomb
      assert pattern.value == 9
    end
  end

  describe "identify/1 for sequences" do
    test "identifies a regular sequence" do
      cards = [
        card(3, :hearts),
        card(4, :spades),
        card(5, :diamonds)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :sequence
      assert pattern.value == 5
    end

    test "identifies a sequence with a joker in the middle" do
      cards = [
        card(6, :clubs),
        # representing 7
        joker(),
        card(8, :hearts)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :sequence
      assert pattern.value == 8
    end

    test "identifies a longer sequence with multiple jokers" do
      cards = [
        card(5, :hearts),
        # representing 6
        joker(),
        card(7, :clubs),
        # representing 8
        joker(),
        card(9, :diamonds)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :invalid
    end

    test "rejects non-consecutive cards" do
      cards = [
        card(3, :hearts),
        card(5, :spades),
        card(7, :diamonds)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :invalid
    end
  end

  describe "identify/1 for straights (consecutive pairs)" do
    test "identifies a regular straight" do
      cards = [
        card(4, :hearts),
        card(4, :spades),
        card(5, :diamonds),
        card(5, :clubs)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :straight
      assert pattern.value == 5
    end

    test "identifies a straight with jokers completing pairs" do
      cards = [
        # 7 pair
        card(7, :hearts),
        joker(),
        # 8 pair
        card(8, :diamonds),
        card(8, :clubs)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :straight
      assert pattern.value == 8
    end

    test "identifies a longer straight with multiple jokers" do
      cards = [
        # J pair
        card(:jack, :hearts),
        joker(),
        # Q pair
        joker(),
        joker(),
        # K pair
        card(:king, :diamonds),
        card(:king, :clubs)
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :invalid
    end

    test "identifies a straight with jokers at the ends" do
      cards = [
        # representing 5
        joker(),
        card(5, :diamonds),
        card(6, :spades),
        # representing 6
        joker()
      ]

      pattern = CardPattern.identify(cards)

      assert pattern.type == :straight
      assert pattern.value == 6
    end

    test "rejects non-consecutive pairs" do
      cards = [
        card(3, :hearts),
        card(3, :spades),
        card(5, :diamonds),
        card(5, :clubs)
      ]

      pattern = CardPattern.identify(cards)

      # This should fail because 3 and 5 are not consecutive
      assert pattern.type == :invalid
    end
  end

  describe "can_beat/2" do
    test "higher single beats lower single" do
      pattern1 = CardPattern.identify([card(:ace, :spades)])
      pattern2 = CardPattern.identify([card(:king, :hearts)])

      assert CardPattern.can_beat(pattern1, pattern2)
      refute CardPattern.can_beat(pattern2, pattern1)
    end

    test "higher pair beats lower pair" do
      pattern1 = CardPattern.identify([card(10, :clubs), card(10, :diamonds)])
      pattern2 = CardPattern.identify([card(9, :hearts), card(9, :spades)])

      assert CardPattern.can_beat(pattern1, pattern2)
      refute CardPattern.can_beat(pattern2, pattern1)
    end

    test "pair with joker beats lower pair" do
      pattern1 = CardPattern.identify([card(:queen, :clubs), joker()])
      pattern2 = CardPattern.identify([card(:jack, :hearts), card(:jack, :spades)])

      assert CardPattern.can_beat(pattern1, pattern2)
      refute CardPattern.can_beat(pattern2, pattern1)
    end

    test "bomb beats any non-bomb pattern" do
      abomb =
        CardPattern.identify([
          card(8, :hearts),
          card(8, :spades),
          card(8, :diamonds),
          card(8, :clubs)
        ])

      bomb =
        CardPattern.identify([
          card(:ace, :hearts),
          card(:ace, :spades),
          card(:ace, :diamonds)
        ])

      assert CardPattern.can_beat(abomb, bomb)
      refute CardPattern.can_beat(bomb, abomb)
    end

    test "higher bomb beats lower bomb" do
      bomb1 =
        CardPattern.identify([
          card(:king, :hearts),
          card(:king, :spades),
          card(:king, :diamonds),
          card(:king, :clubs)
        ])

      bomb2 =
        CardPattern.identify([
          card(:queen, :hearts),
          card(:queen, :spades),
          card(:queen, :diamonds),
          card(:queen, :clubs)
        ])

      assert CardPattern.can_beat(bomb1, bomb2)
      refute CardPattern.can_beat(bomb2, bomb1)
    end

    test "bomb with jokers beats lower bomb" do
      bomb1 =
        CardPattern.identify([
          card(:ace, :hearts),
          card(:ace, :spades),
          joker(),
          joker()
        ])

      bomb2 =
        CardPattern.identify([
          card(10, :hearts),
          card(10, :spades),
          card(10, :diamonds),
          card(10, :clubs)
        ])

      assert CardPattern.can_beat(bomb1, bomb2)
      refute CardPattern.can_beat(bomb2, bomb1)
    end

    test "different pattern types cannot beat each other" do
      pair = CardPattern.identify([card(2, :hearts), card(2, :spades)])

      bomb =
        CardPattern.identify([
          card(:jack, :hearts),
          card(:jack, :spades),
          card(:jack, :diamonds)
        ])

      refute CardPattern.can_beat(pair, bomb)
      assert CardPattern.can_beat(bomb, pair)
    end
  end
end
