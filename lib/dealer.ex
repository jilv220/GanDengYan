defmodule Dealer do
  @spec shuffle(Deck.t()) :: Deck.t()
  def shuffle(deck \\ Deck.make()) do
    Enum.shuffle(deck)
  end

  @spec deal(Deck.t(), [Player.t()]) :: {[Player.t()], Deck.t()}
  def deal(deck, players) when is_list(players) and length(players) > 0 do
    # Find the banker or set first player as banker if none exists
    players_with_banker =
      if Enum.any?(players, & &1.is_banker) do
        players
      else
        List.update_at(players, 0, &%Player{&1 | is_banker: true})
      end

    # Deal cards to players
    # Distribute cards as evenly as possible
    num_players = length(players_with_banker)
    cards_per_player = div(length(deck), num_players)
    remainder = rem(length(deck), num_players)

    {updated_players, _} =
      Enum.map_reduce(players_with_banker, {deck, 0}, fn player, {remaining_deck, idx} ->
        # Banker gets one extra card if there's a remainder
        extra = if player.is_banker and remainder > 0, do: 1, else: 0
        player_count = cards_per_player + extra

        {player_cards, new_remaining} = Enum.split(remaining_deck, player_count)
        updated_player = %Player{player | hand: player_cards}

        {updated_player, {new_remaining, idx + 1}}
      end)

    # Empty deck after dealing
    {updated_players, []}
  end
end
