defmodule Lux.Lenses.Hyperliquid.Metadata do
  @moduledoc """
  Lens for fetching asset metadata and universe from the Hyperliquid API.

  Returns the full universe of tradable assets including their specifications
  (name, szDecimals, etc.) and current market metadata.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.Metadata.focus(%{})
      {:ok, %{universe: [%{name: "BTC", szDecimals: 5, ...}], ...}}
  """

  use Lux.Lens,
    name: "Hyperliquid Metadata",
    description: "Fetches asset metadata and universe from Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def before_focus(params) do
    Map.put(params, :type, "metadata")
  end

  @impl true
  def after_focus(response) do
    {:ok, response}
  end
end
