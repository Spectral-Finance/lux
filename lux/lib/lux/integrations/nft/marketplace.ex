defmodule Lux.Integrations.Nft.Marketplace do
  @moduledoc """
  NFT marketplace aggregation helpers.

  This module keeps marketplace-specific API calls outside of the aggregation
  core. Lenses can fetch data from OpenSea, Blur, X2Y2, or another source and
  pass normalized maps here for deterministic collection statistics, price
  tracking, sales monitoring, rarity scoring, market trends, and
  cross-marketplace reports.
  """

  @type marketplace :: atom() | String.t()
  @type nft_trait :: %{trait_type: String.t(), value: String.t()}
  @type listing :: %{
          marketplace: String.t(),
          collection: String.t(),
          token_id: String.t() | nil,
          price: float(),
          currency: String.t(),
          seller: String.t() | nil,
          url: String.t() | nil,
          status: String.t()
        }
  @type sale :: %{
          marketplace: String.t(),
          collection: String.t(),
          token_id: String.t() | nil,
          price: float(),
          currency: String.t(),
          buyer: String.t() | nil,
          seller: String.t() | nil,
          timestamp: String.t() | nil
        }

  @doc """
  Aggregates collection-level stats across marketplaces.
  """
  @spec collection_stats([map()]) :: map()
  def collection_stats(collections) when is_list(collections) do
    normalized = Enum.map(collections, &normalize_collection/1)

    %{
      marketplaces: Enum.map(normalized, & &1.marketplace) |> Enum.uniq(),
      collection_count: length(normalized),
      floor_price: normalized |> Enum.map(& &1.floor_price) |> min_positive(),
      total_volume: normalized |> Enum.map(& &1.volume) |> Enum.sum() |> round_float(),
      total_owners: normalized |> Enum.map(& &1.owners) |> Enum.sum(),
      total_supply: normalized |> Enum.map(& &1.supply) |> Enum.max(fn -> 0 end),
      by_marketplace: Map.new(normalized, &{&1.marketplace, &1})
    }
  end

  @doc """
  Normalizes active marketplace listings and summarizes floor/average prices.
  """
  @spec price_tracking([map()]) :: map()
  def price_tracking(listings) when is_list(listings) do
    normalized =
      listings
      |> Enum.map(&normalize_listing/1)
      |> Enum.filter(&(&1.price > 0 and &1.status == "active"))

    by_marketplace =
      normalized
      |> Enum.group_by(& &1.marketplace)
      |> Map.new(fn {marketplace, market_listings} ->
        {marketplace, price_summary(market_listings)}
      end)

    %{
      listing_count: length(normalized),
      floor_price: normalized |> Enum.map(& &1.price) |> min_positive(),
      average_price: normalized |> Enum.map(& &1.price) |> average(),
      median_price: normalized |> Enum.map(& &1.price) |> median(),
      by_marketplace: by_marketplace,
      cheapest_listing: Enum.min_by(normalized, & &1.price, fn -> nil end),
      listings: Enum.sort_by(normalized, & &1.price)
    }
  end

  @doc """
  Filters and summarizes NFT sales for collection monitoring.
  """
  @spec sales_monitor([map()], map()) :: map()
  def sales_monitor(sales, opts \\ %{}) when is_list(sales) do
    normalized =
      sales
      |> Enum.map(&normalize_sale/1)
      |> Enum.filter(&sale_matches?(&1, opts))
      |> Enum.sort_by(&timestamp_sort_key/1, :desc)

    prices = Enum.map(normalized, & &1.price)

    %{
      sale_count: length(normalized),
      total_volume: Enum.sum(prices) |> round_float(),
      average_sale_price: average(prices),
      highest_sale: Enum.max_by(normalized, & &1.price, fn -> nil end),
      lowest_sale: Enum.min_by(normalized, & &1.price, fn -> nil end),
      sales: normalized
    }
  end

  @doc """
  Scores tokens by trait frequency and returns rarity ranks.

  Rarer trait values receive higher weights. Tokens are sorted from rarest to
  most common.
  """
  @spec rarity_scores([map()]) :: map()
  def rarity_scores(tokens) when is_list(tokens) do
    normalized = Enum.map(tokens, &normalize_token/1)
    supply = max(length(normalized), 1)
    frequencies = trait_frequencies(normalized)

    ranked =
      normalized
      |> Enum.map(&score_token(&1, frequencies, supply))
      |> Enum.sort_by(& &1.rarity_score, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {token, rank} -> Map.put(token, :rarity_rank, rank) end)

    %{
      supply: length(normalized),
      trait_frequencies: frequencies,
      tokens: ranked
    }
  end

  @doc """
  Builds period buckets and deltas for marketplace trend analysis.
  """
  @spec market_trends([map()], map()) :: map()
  def market_trends(sales, opts \\ %{}) when is_list(sales) do
    bucket = value(opts, :bucket) || :daily

    buckets =
      sales
      |> Enum.map(&normalize_sale/1)
      |> Enum.group_by(&bucket_key(&1.timestamp, bucket))
      |> Map.new(fn {period, period_sales} ->
        prices = Enum.map(period_sales, & &1.price)

        {period,
         %{
           period: period,
           sale_count: length(period_sales),
           volume: Enum.sum(prices) |> round_float(),
           average_price: average(prices),
           floor_price: min_positive(prices)
         }}
      end)
      |> Map.values()
      |> Enum.sort_by(& &1.period)

    %{
      bucket: bucket,
      periods: buckets,
      volume_delta: delta(buckets, :volume),
      sales_delta: delta(buckets, :sale_count),
      floor_delta: delta(buckets, :floor_price)
    }
  end

  @doc """
  Produces a single cross-marketplace NFT analytics report.
  """
  @spec cross_marketplace_report(map()) :: map()
  def cross_marketplace_report(attrs) when is_map(attrs) do
    collections = value(attrs, :collections) || []
    listings = value(attrs, :listings) || []
    sales = value(attrs, :sales) || []
    tokens = value(attrs, :tokens) || []

    collection_stats = collection_stats(collections)
    price_tracking = price_tracking(listings)
    sales_monitor = sales_monitor(sales)
    trends = market_trends(sales, %{bucket: value(attrs, :trend_bucket) || :daily})
    rarity = rarity_scores(tokens)

    %{
      collection: collection_stats,
      prices: price_tracking,
      sales: sales_monitor,
      trends: trends,
      rarity: rarity,
      marketplace_comparison: marketplace_comparison(collection_stats, price_tracking, sales)
    }
  end

  @doc false
  @spec normalize_collection(map()) :: map()
  def normalize_collection(attrs) when is_map(attrs) do
    %{
      marketplace: normalize_marketplace(value(attrs, :marketplace)),
      slug: string(value(attrs, :slug) || value(attrs, :collection) || value(attrs, :name)),
      name: string(value(attrs, :name) || value(attrs, :slug) || value(attrs, :collection)),
      floor_price: number(value(attrs, :floor_price) || value(attrs, :floor)),
      volume: number(value(attrs, :volume) || value(attrs, :total_volume)),
      owners: integer(value(attrs, :owners) || value(attrs, :owner_count)),
      supply: integer(value(attrs, :supply) || value(attrs, :total_supply)),
      listed_count: integer(value(attrs, :listed_count) || value(attrs, :listings))
    }
  end

  @doc false
  @spec normalize_listing(map()) :: listing()
  def normalize_listing(attrs) when is_map(attrs) do
    %{
      marketplace: normalize_marketplace(value(attrs, :marketplace)),
      collection: string(value(attrs, :collection) || value(attrs, :slug)),
      token_id: optional_string(value(attrs, :token_id) || value(attrs, :id)),
      price: number(value(attrs, :price) || value(attrs, :amount)),
      currency: string(value(attrs, :currency) || "ETH") |> String.upcase(),
      seller: optional_string(value(attrs, :seller)),
      url: optional_string(value(attrs, :url)),
      status: string(value(attrs, :status) || "active") |> String.downcase()
    }
  end

  @doc false
  @spec normalize_sale(map()) :: sale()
  def normalize_sale(attrs) when is_map(attrs) do
    %{
      marketplace: normalize_marketplace(value(attrs, :marketplace)),
      collection: string(value(attrs, :collection) || value(attrs, :slug)),
      token_id: optional_string(value(attrs, :token_id) || value(attrs, :id)),
      price: number(value(attrs, :price) || value(attrs, :amount)),
      currency: string(value(attrs, :currency) || "ETH") |> String.upcase(),
      buyer: optional_string(value(attrs, :buyer)),
      seller: optional_string(value(attrs, :seller)),
      timestamp: optional_string(value(attrs, :timestamp) || value(attrs, :sold_at))
    }
  end

  @doc false
  @spec normalize_token(map()) :: map()
  def normalize_token(attrs) when is_map(attrs) do
    %{
      token_id: optional_string(value(attrs, :token_id) || value(attrs, :id)),
      collection: string(value(attrs, :collection) || value(attrs, :slug)),
      name: optional_string(value(attrs, :name)),
      traits: normalize_traits(value(attrs, :traits) || value(attrs, :attributes) || %{})
    }
  end

  defp marketplace_comparison(collection_stats, price_tracking, sales) do
    sale_volume_by_marketplace =
      sales
      |> Enum.map(&normalize_sale/1)
      |> Enum.group_by(& &1.marketplace)
      |> Map.new(fn {marketplace, market_sales} ->
        {marketplace, market_sales |> Enum.map(& &1.price) |> Enum.sum() |> round_float()}
      end)

    collection_stats.by_marketplace
    |> Map.keys()
    |> Kernel.++(Map.keys(price_tracking.by_marketplace))
    |> Kernel.++(Map.keys(sale_volume_by_marketplace))
    |> Enum.uniq()
    |> Map.new(fn marketplace ->
      collection = Map.get(collection_stats.by_marketplace, marketplace, %{})
      prices = Map.get(price_tracking.by_marketplace, marketplace, %{})

      {marketplace,
       %{
         floor_price: Map.get(prices, :floor_price) || Map.get(collection, :floor_price, 0.0),
         listing_count: Map.get(prices, :listing_count, 0),
         collection_volume: Map.get(collection, :volume, 0.0),
         sales_volume: Map.get(sale_volume_by_marketplace, marketplace, 0.0),
         owner_count: Map.get(collection, :owners, 0)
       }}
    end)
  end

  defp price_summary(listings) do
    prices = Enum.map(listings, & &1.price)

    %{
      listing_count: length(listings),
      floor_price: min_positive(prices),
      average_price: average(prices),
      median_price: median(prices)
    }
  end

  defp sale_matches?(sale, opts) do
    collection = optional_string(value(opts, :collection))
    marketplace = optional_string(value(opts, :marketplace)) |> normalize_optional_marketplace()
    min_price = value(opts, :min_price)
    since = optional_string(value(opts, :since))

    Enum.all?([
      is_nil(collection) or sale.collection == collection,
      is_nil(marketplace) or sale.marketplace == marketplace,
      is_nil(min_price) or sale.price >= number(min_price),
      is_nil(since) or is_nil(sale.timestamp) or sale.timestamp >= since
    ])
  end

  defp trait_frequencies(tokens) do
    tokens
    |> Enum.flat_map(& &1.traits)
    |> Enum.frequencies_by(&{&1.trait_type, &1.value})
    |> Map.new(fn {{trait_type, value}, count} ->
      {"#{trait_type}:#{value}", count}
    end)
  end

  defp score_token(token, frequencies, supply) do
    score =
      token.traits
      |> Enum.map(fn trait ->
        Map.get(frequencies, "#{trait.trait_type}:#{trait.value}", supply)
      end)
      |> Enum.map(&(supply / &1))
      |> Enum.sum()
      |> round_float()

    Map.put(token, :rarity_score, score)
  end

  defp normalize_traits(traits) when is_map(traits) do
    traits
    |> Enum.map(fn {trait_type, value} ->
      %{trait_type: string(trait_type), value: string(value)}
    end)
    |> Enum.sort_by(&{&1.trait_type, &1.value})
  end

  defp normalize_traits(traits) when is_list(traits) do
    traits
    |> Enum.map(fn
      %{trait_type: trait_type, value: value} -> %{trait_type: string(trait_type), value: string(value)}
      %{"trait_type" => trait_type, "value" => value} -> %{trait_type: string(trait_type), value: string(value)}
      %{type: trait_type, value: value} -> %{trait_type: string(trait_type), value: string(value)}
      {trait_type, value} -> %{trait_type: string(trait_type), value: string(value)}
      other -> %{trait_type: "trait", value: string(other)}
    end)
    |> Enum.sort_by(&{&1.trait_type, &1.value})
  end

  defp normalize_traits(_traits), do: []

  defp bucket_key(nil, _bucket), do: "unknown"

  defp bucket_key(timestamp, :hourly) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> "#{Date.to_iso8601(DateTime.to_date(dt))}T#{pad(dt.hour)}:00:00Z"
      _ -> String.slice(timestamp, 0, 13) <> ":00:00Z"
    end
  end

  defp bucket_key(timestamp, :weekly) do
    with {:ok, date} <- parse_date(timestamp),
         {year, week} <- :calendar.iso_week_number({date.year, date.month, date.day}) do
      "#{year}-W#{pad(week)}"
    else
      _ -> String.slice(timestamp, 0, 10)
    end
  end

  defp bucket_key(timestamp, _daily) do
    timestamp
    |> string()
    |> String.slice(0, 10)
  end

  defp parse_date(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> {:ok, DateTime.to_date(dt)}
      _ -> Date.from_iso8601(String.slice(timestamp, 0, 10))
    end
  end

  defp timestamp_sort_key(%{timestamp: nil}), do: ""
  defp timestamp_sort_key(%{timestamp: timestamp}), do: timestamp

  defp delta([], _key), do: 0.0
  defp delta([_only], _key), do: 0.0

  defp delta(buckets, key) do
    first = buckets |> List.first() |> Map.get(key, 0.0)
    last = buckets |> List.last() |> Map.get(key, 0.0)
    round_float(last - first)
  end

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp normalize_marketplace(nil), do: "unknown"
  defp normalize_marketplace(value), do: value |> string() |> String.downcase()

  defp normalize_optional_marketplace(nil), do: nil
  defp normalize_optional_marketplace(value), do: normalize_marketplace(value)

  defp min_positive(values) do
    values
    |> Enum.map(&number/1)
    |> Enum.filter(&(&1 > 0))
    |> Enum.min(fn -> 0.0 end)
  end

  defp average([]), do: 0.0

  defp average(values) do
    values
    |> Enum.map(&number/1)
    |> then(&(Enum.sum(&1) / max(length(&1), 1)))
    |> round_float()
  end

  defp median([]), do: 0.0

  defp median(values) do
    sorted = values |> Enum.map(&number/1) |> Enum.sort()
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1 do
      Enum.at(sorted, middle)
    else
      ((Enum.at(sorted, middle - 1) || 0.0) + (Enum.at(sorted, middle) || 0.0)) / 2
    end
    |> round_float()
  end

  defp number(nil), do: 0.0
  defp number(value) when is_integer(value), do: value * 1.0
  defp number(value) when is_float(value), do: value

  defp number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end

  defp number(_value), do: 0.0

  defp integer(nil), do: 0
  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: trunc(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _rest} -> number
      :error -> value |> number() |> trunc()
    end
  end

  defp integer(_value), do: 0

  defp optional_string(nil), do: nil
  defp optional_string(""), do: nil
  defp optional_string(value), do: string(value)

  defp string(nil), do: ""
  defp string(value) when is_binary(value), do: value
  defp string(value) when is_atom(value), do: Atom.to_string(value)
  defp string(value), do: to_string(value)

  defp pad(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")
  defp round_float(value), do: Float.round(number(value), 6)
end
