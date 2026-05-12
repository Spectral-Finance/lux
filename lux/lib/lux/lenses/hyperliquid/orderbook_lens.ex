defmodule Lux.Lenses.Hyperliquid.Orderbook do
  @moduledoc """
  Lens for fetching the L2 orderbook for a given coin from the Hyperliquid API.

  Returns the current orderbook levels (bids and asks) with prices and sizes.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.Orderbook.focus(%{coin: "BTC"})
      {:ok, %{"coin" => "BTC", "levels" => [...], "time" => ...}}
  """

  use Lux.Lens,
    name: "Hyperliquid Orderbook",
    description: "Fetches L2 orderbook data from Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "The asset symbol (e.g. BTC, ETH)"
        }
      },
      required: ["coin"]
    }

  def before_focus(params) do
    %{
      type: "l2Book",
      coin: Map.get(params, :coin)
    }
  end

  @impl true
  def after_focus(response) do
    {:ok, response}
  end
end
