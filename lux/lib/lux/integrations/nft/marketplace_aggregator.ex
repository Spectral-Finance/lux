defmodule Lux.Integrations.NFT.MarketplaceAggregator do
  @moduledoc """
  Marketplace-neutral NFT aggregation helpers.

  The module normalizes collection, listing, sale, trait, and rarity data from
  multiple NFT marketplaces. It is transport-free: callers can use the request
  plans to collect marketplace data, then pass normalized or raw payloads into
  `aggregate/1`.
  """

  @known_marketplaces ["opensea", "blur", "x2y2"]

  @doc "Builds request plans for marketplace data collection."
  @spec request_plans(map()) :: [map()]
  def request_plans(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)
    slug = Map.get(attrs, :collection_slug, "COLLECTION_SLUG")
    contract = Map.get(attrs, :contract_address, "CONTRACT_ADDRESS")
    chain = Map.get(attrs, :chain, "ethereum")

    attrs
    |> list(:marketplaces, @known_marketplaces)
    |> Enum.map(&marketplace_name/1)
    |> Enum.flat_map(&marketplace_request_plan(&1, slug, contract, chain))
  end

  @doc "Aggregates marketplace data into collection, price, sale, rarity, and trend reports."
  @spec aggregate(map()) :: map()
  def aggregate(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)
    marketplaces = attrs |> list(:marketplaces, []) |> normalize_marketplace_inputs()
    listings = Enum.flat_map(marketplaces, & &1.listings)
    sales = Enum.flat_map(marketplaces, & &1.sales)
    tokens = attrs |> Map.get(:tokens, []) |> normalize_tokens()
    tokens = tokens ++ Enum.flat_map(marketplaces, & &1.tokens)
    trait_analysis = trait_analysis(tokens)
    rarity = rarity_scores(tokens, trait_analysis.frequencies)
    stats = Enum.map(marketplaces, & &1.stats)

    %{
      collection: collection(attrs),
      request_plans: request_plans(attrs),
      collection_data: collection_data(stats),
      price_tracking: price_tracking(stats),
      sales_monitoring: sales_monitoring(sales),
      rarity: rarity,
      trait_analysis: trait_analysis,
      market_trends: market_trends(stats),
      listing_management: listing_management(listings),
      cross_marketplace_comparison: cross_marketplace_comparison(stats, listings),
      marketplaces: marketplaces,
      coverage: [
        :collection_data_aggregation,
        :price_tracking,
        :sales_monitoring,
        :rarity_scoring,
        :trait_analysis,
        :market_trend_analysis,
        :listing_management,
        :cross_marketplace_comparison
      ]
    }
  end

  defp collection(attrs) do
    %{
      slug: Map.get(attrs, :collection_slug, "COLLECTION_SLUG"),
      contract_address: Map.get(attrs, :contract_address, "CONTRACT_ADDRESS"),
      chain: Map.get(attrs, :chain, "ethereum")
    }
  end

  defp marketplace_request_plan("opensea", slug, contract, chain) do
    [
      request("opensea", :collection_stats, :get, "/api/v2/collections/#{slug}/stats", %{}),
      request("opensea", :listings, :get, "/api/v2/listings/collection/#{slug}/all", %{limit: 100}),
      request("opensea", :sales, :get, "/api/v2/events/collection/#{slug}", %{
        event_type: "sale",
        chain: chain,
        contract_address: contract
      })
    ]
  end

  defp marketplace_request_plan("blur", slug, contract, _chain) do
    [
      request("blur", :collection_stats, :get, "/v1/collections/#{slug}", %{}),
      request("blur", :listings, :get, "/v1/collections/#{slug}/executable-bids", %{
        contract: contract
      }),
      request("blur", :sales, :get, "/v1/collections/#{slug}/transactions", %{contract: contract})
    ]
  end

  defp marketplace_request_plan("x2y2", slug, contract, chain) do
    [
      request("x2y2", :collection_stats, :get, "/v1/collections/#{contract}/stats", %{
        slug: slug,
        chain: chain
      }),
      request("x2y2", :listings, :get, "/v1/orders", %{contract: contract, status: "open"}),
      request("x2y2", :sales, :get, "/v1/events", %{contract: contract, event_type: "sale"})
    ]
  end

  defp marketplace_request_plan(marketplace, slug, contract, chain) do
    [
      request(marketplace, :collection_stats, :get, "/collections/#{slug}/stats", %{
        contract_address: contract,
        chain: chain
      }),
      request(marketplace, :listings, :get, "/collections/#{slug}/listings", %{
        contract_address: contract
      }),
      request(marketplace, :sales, :get, "/collections/#{slug}/sales", %{
        contract_address: contract
      })
    ]
  end

  defp request(marketplace, capability, method, path, params) do
    %{
      marketplace: marketplace,
      capability: capability,
      method: method,
      path: path,
      params: params,
      auth_required: marketplace in ["opensea", "blur", "x2y2"],
      rate_limit_key: "#{marketplace}:#{capability}"
    }
  end

  defp normalize_marketplace_inputs([]), do: []

  defp normalize_marketplace_inputs(marketplaces) do
    Enum.map(marketplaces, fn marketplace ->
      if is_map(marketplace) do
        normalize_marketplace_input(marketplace)
      else
        name = marketplace_name(marketplace)

        %{
          marketplace: name,
          stats: normalize_stats(%{}, name),
          listings: [],
          sales: [],
          tokens: []
        }
      end
    end)
  end

  defp normalize_marketplace_input(marketplace) do
    marketplace = normalize_keys(marketplace)
    name = marketplace |> get(:marketplace, "custom") |> marketplace_name()

    %{
      marketplace: name,
      stats: normalize_stats(get(marketplace, :stats, %{}), name),
      listings: marketplace |> get(:listings, []) |> normalize_listings(name),
      sales: marketplace |> get(:sales, []) |> normalize_sales(name),
      tokens: marketplace |> get(:tokens, []) |> normalize_tokens()
    }
  end

  defp normalize_stats(stats, marketplace) do
    stats = normalize_keys(stats || %{})

    %{
      marketplace: marketplace,
      floor_price: money(get_any(stats, [:floor_price, :floor, :floorPrice])),
      previous_floor_price: money(get_any(stats, [:previous_floor_price, :previousFloorPrice])),
      volume_24h: money(get_any(stats, [:volume_24h, :one_day_volume, :volume1d])),
      volume_7d: money(get_any(stats, [:volume_7d, :seven_day_volume, :volume7d])),
      sales_24h: integer(get_any(stats, [:sales_24h, :one_day_sales, :sales1d])),
      listed_count: integer(get_any(stats, [:listed_count, :listed, :num_listings])),
      owners: integer(get_any(stats, [:owners, :owner_count, :num_owners])),
      currency: get(stats, :currency, "ETH")
    }
  end

  defp normalize_listings(listings, marketplace) when is_list(listings) do
    Enum.map(listings, fn listing ->
      listing = normalize_keys(listing)

      %{
        marketplace: marketplace,
        token_id: get(listing, :token_id, get(listing, :tokenId, "")),
        price: money(get_any(listing, [:price, :current_price, :amount])),
        currency: get(listing, :currency, "ETH"),
        seller: get(listing, :seller, ""),
        url: get(listing, :url, ""),
        expires_at: get(listing, :expires_at, nil)
      }
    end)
  end

  defp normalize_listings(_, _marketplace), do: []

  defp normalize_sales(sales, marketplace) when is_list(sales) do
    Enum.map(sales, fn sale ->
      sale = normalize_keys(sale)

      %{
        marketplace: marketplace,
        token_id: get(sale, :token_id, get(sale, :tokenId, "")),
        price: money(get_any(sale, [:price, :sale_price, :amount])),
        currency: get(sale, :currency, "ETH"),
        buyer: get(sale, :buyer, ""),
        seller: get(sale, :seller, ""),
        sold_at: get_any(sale, [:sold_at, :timestamp, :created_at])
      }
    end)
  end

  defp normalize_sales(_, _marketplace), do: []

  defp normalize_tokens(tokens) when is_list(tokens) do
    Enum.map(tokens, fn token ->
      token = normalize_keys(token)

      %{
        token_id: get(token, :token_id, get(token, :tokenId, "")),
        traits: normalize_traits(get(token, :traits, [])),
        metadata: get(token, :metadata, %{})
      }
    end)
  end

  defp normalize_tokens(_), do: []

  defp normalize_traits(traits) when is_list(traits) do
    Enum.map(traits, fn trait ->
      trait = normalize_keys(trait)

      %{
        type: get_any(trait, [:type, :trait_type, :traitType]),
        value: get(trait, :value, "")
      }
    end)
  end

  defp normalize_traits(traits) when is_map(traits) do
    Enum.map(traits, fn {type, value} -> %{type: to_string(type), value: to_string(value)} end)
  end

  defp normalize_traits(_), do: []

  defp collection_data(stats) do
    %{
      marketplaces: length(stats),
      floor_prices: map_by_market(stats, :floor_price),
      volume_24h: sum_values(stats, :volume_24h),
      volume_7d: sum_values(stats, :volume_7d),
      listed_count: sum_values(stats, :listed_count),
      owners: stats |> Enum.map(& &1.owners) |> Enum.filter(& &1) |> max_or_nil()
    }
  end

  defp price_tracking(stats) do
    floors = Enum.filter(stats, &number?(&1.floor_price))
    lowest = min_by(floors, & &1.floor_price)
    highest = max_by(floors, & &1.floor_price)

    %{
      by_marketplace: map_by_market(stats, :floor_price),
      lowest_floor: floor_summary(lowest),
      highest_floor: floor_summary(highest),
      average_floor: average(Enum.map(floors, & &1.floor_price)),
      spread_percent: spread_percent(lowest, highest)
    }
  end

  defp sales_monitoring(sales) do
    prices = sales |> Enum.map(& &1.price) |> Enum.filter(&number?/1)

    %{
      sales_count: length(sales),
      total_volume: sum(prices),
      average_sale_price: average(prices),
      recent_sales: Enum.sort_by(sales, &to_string(&1.sold_at || ""), :desc)
    }
  end

  defp trait_analysis(tokens) do
    total = max(length(tokens), 1)

    frequencies =
      tokens
      |> Enum.flat_map(& &1.traits)
      |> Enum.frequencies_by(&trait_key/1)
      |> Enum.map(fn {key, count} ->
        {type, value} = split_trait_key(key)

        %{
          trait_type: type,
          value: value,
          count: count,
          frequency: round_float(count / total)
        }
      end)
      |> Enum.sort_by(&{&1.trait_type, &1.value})

    %{
      token_count: length(tokens),
      trait_types: frequencies |> Enum.map(& &1.trait_type) |> Enum.uniq(),
      frequencies: frequencies
    }
  end

  defp rarity_scores([], _frequencies), do: %{tokens: [], top_tokens: []}

  defp rarity_scores(tokens, frequencies) do
    frequency_by_key =
      Map.new(frequencies, fn trait -> {"#{trait.trait_type}:#{trait.value}", trait.frequency} end)

    scored =
      Enum.map(tokens, fn token ->
        score =
          token.traits
          |> Enum.map(&Map.get(frequency_by_key, trait_key(&1), 1.0))
          |> Enum.reduce(0.0, fn frequency, acc -> acc + 1 / max(frequency, 0.000_001) end)
          |> round_float()

        Map.put(token, :rarity_score, score)
      end)
      |> Enum.sort_by(& &1.rarity_score, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {token, rank} -> Map.put(token, :rarity_rank, rank) end)

    %{tokens: scored, top_tokens: Enum.take(scored, 10)}
  end

  defp market_trends(stats) do
    trends =
      stats
      |> Enum.map(fn item ->
        change = percent_change(item.previous_floor_price, item.floor_price)

        %{
          marketplace: item.marketplace,
          floor_change_percent: change,
          sales_24h: item.sales_24h,
          volume_24h: item.volume_24h,
          trend: trend_label(change)
        }
      end)

    %{
      by_marketplace: trends,
      overall_trend:
        trends
        |> Enum.map(& &1.floor_change_percent)
        |> Enum.filter(&number?/1)
        |> average_trend()
    }
  end

  defp listing_management(listings) do
    active = Enum.filter(listings, &number?(&1.price))

    %{
      active_count: length(active),
      by_marketplace: Enum.frequencies_by(active, & &1.marketplace),
      lowest_listing: min_by(active, & &1.price),
      listings: Enum.sort_by(active, & &1.price)
    }
  end

  defp cross_marketplace_comparison(stats, listings) do
    floors = Enum.filter(stats, &number?(&1.floor_price))

    %{
      marketplace_count: length(stats),
      lowest_floor_marketplace: floor_summary(min_by(floors, & &1.floor_price)),
      highest_liquidity_marketplace: floor_summary(max_by(stats, &(&1.listed_count || 0))),
      arbitrage_candidates: arbitrage_candidates(floors),
      listing_overlap:
        listings |> Enum.map(& &1.token_id) |> Enum.reject(&(&1 == "")) |> duplicate_count()
    }
  end

  defp arbitrage_candidates(floors) do
    for buy <- floors,
        sell <- floors,
        buy.marketplace != sell.marketplace,
        sell.floor_price > buy.floor_price do
      %{
        buy_marketplace: buy.marketplace,
        sell_marketplace: sell.marketplace,
        buy_floor: buy.floor_price,
        sell_floor: sell.floor_price,
        spread_percent: round_float((sell.floor_price - buy.floor_price) / buy.floor_price * 100)
      }
    end
    |> Enum.filter(&(&1.spread_percent >= 5.0))
    |> Enum.sort_by(& &1.spread_percent, :desc)
    |> Enum.take(5)
  end

  defp map_by_market(items, field) do
    Map.new(items, &{&1.marketplace, Map.get(&1, field)})
  end

  defp floor_summary(nil), do: nil

  defp floor_summary(item) do
    %{
      marketplace: item.marketplace,
      floor_price: item.floor_price,
      listed_count: item.listed_count,
      volume_24h: item.volume_24h
    }
  end

  defp spread_percent(nil, _highest), do: nil
  defp spread_percent(_lowest, nil), do: nil
  defp spread_percent(%{floor_price: price}, _) when price in [nil, 0], do: nil

  defp spread_percent(lowest, highest) do
    round_float((highest.floor_price - lowest.floor_price) / lowest.floor_price * 100)
  end

  defp percent_change(previous, current) when previous in [nil, 0] or current in [nil, 0], do: nil
  defp percent_change(previous, current), do: round_float((current - previous) / previous * 100)

  defp trend_label(nil), do: :insufficient_history
  defp trend_label(change) when change > 2.0, do: :up
  defp trend_label(change) when change < -2.0, do: :down
  defp trend_label(_), do: :flat

  defp average_trend([]), do: :insufficient_history

  defp average_trend(changes) do
    changes |> average() |> trend_label()
  end

  defp duplicate_count(values) do
    values
    |> Enum.frequencies()
    |> Enum.count(fn {_value, count} -> count > 1 end)
  end

  defp min_by([], _fun), do: nil
  defp min_by(items, fun), do: Enum.min_by(items, fun)

  defp max_by([], _fun), do: nil
  defp max_by(items, fun), do: Enum.max_by(items, fun)

  defp max_or_nil([]), do: nil
  defp max_or_nil(values), do: Enum.max(values)

  defp sum_values(items, field) do
    items |> Enum.map(&Map.get(&1, field)) |> Enum.filter(&number?/1) |> sum()
  end

  defp sum(values), do: values |> Enum.sum() |> round_float()

  defp average([]), do: nil
  defp average(values), do: round_float(Enum.sum(values) / length(values))

  defp money(nil), do: nil
  defp money(value) when is_integer(value), do: value * 1.0
  defp money(value) when is_float(value), do: value

  defp money(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp money(_), do: nil

  defp integer(nil), do: nil
  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: round(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp integer(_), do: nil

  defp number?(value), do: is_integer(value) or is_float(value)
  defp round_float(nil), do: nil
  defp round_float(value), do: Float.round(value * 1.0, 6)

  defp trait_key(%{type: type, value: value}), do: "#{type}:#{value}"

  defp split_trait_key(key) do
    case String.split(key, ":", parts: 2) do
      [type, value] -> {type, value}
      [value] -> {"unknown", value}
    end
  end

  defp normalize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp normalize_keys(value), do: value

  defp known_key("collection_slug"), do: :collection_slug
  defp known_key("contract_address"), do: :contract_address
  defp known_key("chain"), do: :chain
  defp known_key("marketplace"), do: :marketplace
  defp known_key("marketplaces"), do: :marketplaces
  defp known_key("stats"), do: :stats
  defp known_key("listings"), do: :listings
  defp known_key("sales"), do: :sales
  defp known_key("tokens"), do: :tokens
  defp known_key("traits"), do: :traits
  defp known_key("metadata"), do: :metadata
  defp known_key("token_id"), do: :token_id
  defp known_key("tokenId"), do: :tokenId
  defp known_key("trait_type"), do: :trait_type
  defp known_key("traitType"), do: :traitType
  defp known_key("floor_price"), do: :floor_price
  defp known_key("floor"), do: :floor
  defp known_key("floorPrice"), do: :floorPrice
  defp known_key("previous_floor_price"), do: :previous_floor_price
  defp known_key("previousFloorPrice"), do: :previousFloorPrice
  defp known_key("volume_24h"), do: :volume_24h
  defp known_key("one_day_volume"), do: :one_day_volume
  defp known_key("volume1d"), do: :volume1d
  defp known_key("volume_7d"), do: :volume_7d
  defp known_key("seven_day_volume"), do: :seven_day_volume
  defp known_key("volume7d"), do: :volume7d
  defp known_key("sales_24h"), do: :sales_24h
  defp known_key("one_day_sales"), do: :one_day_sales
  defp known_key("sales1d"), do: :sales1d
  defp known_key("listed_count"), do: :listed_count
  defp known_key("listed"), do: :listed
  defp known_key("num_listings"), do: :num_listings
  defp known_key("owners"), do: :owners
  defp known_key("owner_count"), do: :owner_count
  defp known_key("num_owners"), do: :num_owners
  defp known_key("currency"), do: :currency
  defp known_key("price"), do: :price
  defp known_key("current_price"), do: :current_price
  defp known_key("amount"), do: :amount
  defp known_key("sale_price"), do: :sale_price
  defp known_key("seller"), do: :seller
  defp known_key("buyer"), do: :buyer
  defp known_key("url"), do: :url
  defp known_key("expires_at"), do: :expires_at
  defp known_key("sold_at"), do: :sold_at
  defp known_key("timestamp"), do: :timestamp
  defp known_key("created_at"), do: :created_at
  defp known_key("type"), do: :type
  defp known_key("value"), do: :value
  defp known_key(key), do: key

  defp get(map, key, default), do: Map.get(map, key, default)

  defp get_any(map, keys) do
    Enum.find_value(keys, &Map.get(map, &1))
  end

  defp list(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_list(value) -> Enum.map(value, &normalize_list_item/1)
      value when is_binary(value) -> [String.downcase(value)]
      _ -> default
    end
  end

  defp normalize_list_item(value) when is_binary(value), do: String.downcase(value)

  defp normalize_list_item(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.downcase()

  defp normalize_list_item(value), do: value

  defp marketplace_name(%{marketplace: marketplace}), do: marketplace_name(marketplace)
  defp marketplace_name(%{"marketplace" => marketplace}), do: marketplace_name(marketplace)

  defp marketplace_name(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.downcase()

  defp marketplace_name(value) when is_binary(value), do: String.downcase(value)
  defp marketplace_name(_), do: "custom"
end
