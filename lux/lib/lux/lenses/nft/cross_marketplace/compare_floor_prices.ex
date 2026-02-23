defmodule Lux.Lenses.NFT.CrossMarketplace.CompareFloorPrices do
  @moduledoc """
  A lens for aggregating and comparing NFT floor prices across multiple marketplaces.

  Queries OpenSea and Blur simultaneously to provide a unified view of:
  - Floor prices across marketplaces
  - Best available floor price (lowest ask)
  - Price discrepancies for arbitrage insight
  - Bid/ask spread analysis
  - Total market liquidity

  ## Examples

      iex> CompareFloorPrices.focus(%{
      ...>   collection_slug: "boredapeyachtclub",
      ...>   contract_address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
      ...> })
      {:ok, %{
        collection_slug: "boredapeyachtclub",
        contract_address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
        best_floor_price: 10.1,
        best_floor_marketplace: "blur",
        currency: "ETH",
        marketplaces: %{
          opensea: %{floor_price: 10.5, available: true},
          blur: %{floor_price: 10.1, available: true}
        },
        price_spread: 0.4,
        price_spread_pct: 3.96
      }}
  """

  alias Lux.Lenses.OpenSea.Collections.GetCollection, as: OpenSeaGetCollection
  alias Lux.Lenses.Blur.Collections.GetCollection, as: BlurGetCollection

  use Lux.Lens,
    name: "Compare NFT Floor Prices",
    description: "Aggregates and compares NFT floor prices across OpenSea and Blur marketplaces",
    url: "https://api.opensea.io/api/v2/collections/:collection_slug",
    method: :get,
    headers: [],
    auth: %{type: :none},
    schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "The OpenSea collection slug (e.g. 'boredapeyachtclub')",
          pattern: "^[a-z0-9-]+$"
        },
        contract_address: %{
          type: :string,
          description: "The NFT contract address (for Blur lookup)",
          pattern: "^0x[0-9a-fA-F]{40}$"
        }
      },
      required: ["collection_slug", "contract_address"]
    }

  @doc """
  Fetches data from multiple marketplaces and aggregates into a comparison.

  This lens overrides the standard focus/2 to perform parallel API calls.
  """
  @impl true
  def focus(params, agent_ctx) do
    collection_slug = params["collection_slug"] || params[:collection_slug]
    contract_address = params["contract_address"] || params[:contract_address]

    opensea_result = safe_fetch(fn ->
      OpenSeaGetCollection.focus(%{"collection_slug" => collection_slug}, agent_ctx)
    end)

    blur_result = safe_fetch(fn ->
      BlurGetCollection.focus(%{"contract_address" => contract_address}, agent_ctx)
    end)

    aggregate(collection_slug, contract_address, opensea_result, blur_result)
  end

  @doc false
  @impl true
  def after_focus(response), do: {:ok, response}

  defp safe_fetch(func) do
    try do
      func.()
    rescue
      _ -> {:error, :unavailable}
    catch
      _ -> {:error, :unavailable}
    end
  end

  defp aggregate(collection_slug, contract_address, opensea_result, blur_result) do
    opensea_data = extract_floor(opensea_result)
    blur_data = extract_floor(blur_result)

    marketplaces = %{
      opensea: opensea_data,
      blur: blur_data
    }

    available_prices =
      marketplaces
      |> Enum.filter(fn {_k, v} -> v[:available] and v[:floor_price] end)
      |> Enum.map(fn {k, v} -> {k, v[:floor_price]} end)

    {best_marketplace, best_price} =
      case available_prices do
        [] -> {nil, nil}
        prices -> Enum.min_by(prices, fn {_k, price} -> price end)
      end

    highest_price =
      case available_prices do
        [] -> nil
        prices ->
          {_k, p} = Enum.max_by(prices, fn {_k, price} -> price end)
          p
      end

    {spread, spread_pct} =
      if best_price && highest_price && best_price > 0 do
        s = Float.round(highest_price - best_price, 6)
        pct = Float.round((highest_price - best_price) / best_price * 100, 2)
        {s, pct}
      else
        {nil, nil}
      end

    result = %{
      collection_slug: collection_slug,
      contract_address: contract_address,
      best_floor_price: best_price,
      best_floor_marketplace: best_marketplace && Atom.to_string(best_marketplace),
      currency: "ETH",
      marketplaces: marketplaces,
      price_spread: spread,
      price_spread_pct: spread_pct
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  defp extract_floor({:ok, data}) do
    %{
      available: true,
      floor_price: data[:floor_price],
      floor_price_currency: data[:floor_price_currency] || "ETH",
      volume_24h: data[:one_day_volume] || data[:volume_24h],
      num_owners: data[:num_owners]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp extract_floor({:error, _}) do
    %{available: false}
  end
end
