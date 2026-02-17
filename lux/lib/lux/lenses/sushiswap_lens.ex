defmodule Lux.Lenses.SushiswapLens do
  @moduledoc """
  A lens for fetching real-time liquidity and price data from SushiSwap.
  Utilizes the SushiSwap Subgraph manifold for high-fidelity data extraction.
  """
  use Lux.Lens,
    name: "Sushiswap Lens",
    description: "Fetches price and liquidity depth for specific pairs on SushiSwap.",
    url: "https://api.thegraph.com/subgraphs/name/sushi-v2/v2",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: "object",
      properties: %{
        pair_address: %{type: "string", description: "The contract address of the SushiSwap pair."}
      },
      required: ["pair_address"]
    }

  def after_initialize(state) do
    {:ok, state}
  end

  @doc """
  Transforms the Subgraph response into a more usable format.
  """
  @impl true
  def after_focus(%{"data" => %{"pair" => data}}) do
    {:ok, %{
      status: "success",
      price_usd: data["token0Price"],
      liquidity_usd: data["reserveUSD"],
      timestamp: DateTime.utc_now()
    }}
  end

  @impl true
  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
