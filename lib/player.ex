defmodule Player do
  @type t :: %Player{
          name: String.t(),
          hand: [Card.t()],
          is_banker: boolean()
        }

  defstruct name: "", hand: [], is_banker: false

  @spec show_hand(t()) :: String.t()
  def show_hand(player) do
    cards_str =
      player.hand
      |> Enum.sort_by(fn card -> {-Card.value(card), card.suit} end)
      |> Enum.map(&Card.to_string/1)
      |> Enum.join(", ")

    "#{player.name}'s hand: #{cards_str} (#{length(player.hand)} cards)"
  end
end
