defmodule Lux.Lenses.Hyperliquid.OpenInterest do
  @moduledoc """
  Lens for fetching open interest data for a given coin from the Hyperliquid API.

  Returns the current open interest for the specified perpetual contract.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.OpenInterest.focus(%{coin: "BTC"})
      {:ok, %{...}}
  """

  use Lux.Lens,
    name: "Hyperliquid Open Interest",
    description: "Fetches open interest data from Hyperliquid",
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
      type: "openInterest",
      coin: Map.get(params, :coin)
    }
  end

  @impl true
  def after_focus(response) do
    {:ok, response}
  end
end
