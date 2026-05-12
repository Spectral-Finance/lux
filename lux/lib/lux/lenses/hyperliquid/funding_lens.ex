defmodule Lux.Lenses.Hyperliquid.Funding do
  @moduledoc """
  Lens for fetching all current mid prices from the Hyperliquid API.

  Returns a map of asset symbols to their current mid prices, which can be
  used to calculate funding rates and track real-time prices across all
  perpetual markets.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.Funding.focus(%{})
      {:ok, %{"BTC" => "104050.0", "ETH" => "..."}}
  """

  use Lux.Lens,
    name: "Hyperliquid All Mids",
    description: "Fetches all current mid prices from Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def before_focus(params) do
    Map.put(params, :type, "allMids")
  end

  @impl true
  def after_focus(response) do
    {:ok, response}
  end
end
