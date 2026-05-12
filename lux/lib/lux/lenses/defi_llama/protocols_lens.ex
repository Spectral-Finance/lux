defmodule Lux.Lenses.DeFiLlama.ProtocolsLens do
  @moduledoc """
  Lens for fetching all protocols with TVL data from the DeFiLlama API.

  ## Examples

      iex> Lux.Lenses.DeFiLlama.ProtocolsLens.focus(%{})
      {:ok, [%{name: "Lido", symbol: "LDO", tvl: 1234567890.0, ...}, ...]}

  The response includes:
  - `name`: Protocol name
  - `symbol`: Token symbol
  - `tvl`: Total value locked in USD
  - `chains`: List of chains the protocol is deployed on
  - `change_1d`, `change_7d`, `change_1m`: TVL change percentages
  - And more metadata for each protocol
  """

  use Lux.Lens,
    name: "DeFiLlama Protocols",
    description: "Fetches all DeFi protocols with their current TVL data from DeFiLlama",
    url: "https://api.llama.fi/protocols",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(protocols) when is_list(protocols) do
    transformed =
      Enum.map(protocols, fn p ->
        %{
          name: p["name"],
          symbol: p["symbol"],
          tvl: p["tvl"],
          chains: p["chains"],
          change_1d: p["change_1d"],
          change_7d: p["change_7d"],
          change_1m: p["change_1m"],
          chain_tvls: p["chainTvls"],
          slug: p["slug"],
          description: p["description"],
          url: p["url"],
          category: p["category"]
        }
      end)

    {:ok, transformed}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
