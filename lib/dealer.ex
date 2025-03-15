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
    # Banker always gets 7 cards, others get 6
    {updated_players, remaining_deck} =
      Enum.map_reduce(players_with_banker, deck, fn player, remaining_deck ->
        # Banker gets 7 cards, others get 6
        cards_to_deal = if player.is_banker, do: 7, else: 6

        {player_cards, new_remaining} = Enum.split(remaining_deck, cards_to_deal)
        updated_player = %Player{player | hand: player_cards}

        {updated_player, new_remaining}
      end)

    # Return updated players and remaining deck
    {updated_players, remaining_deck}
  end
end
