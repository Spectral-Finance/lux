defmodule Lux.Integrations.Hyperliquid.AssetResolver do
  @moduledoc """
  Resolves Hyperliquid asset metadata: asset IDs, tick size, lot size.

  Loads metadata from the Hyperliquid exchange info endpoint (`meta` type)
  and caches with a 5-minute TTL. Provides fixture-based fallbacks
  for common assets during testing or API unavailability.

  ## Usage

      # Resolve metadata for a specific coin
      AssetResolver.resolve("ETH")
      # => %{asset_id: 1, asset_name: "ETH", sz_decimals: 5, tick_size: 0.00001}

      # Get all known assets
      AssetResolver.all_assets()
      # => [%{asset_id: 1, asset_name: "ETH", ...}, ...]

      # Force refresh the metadata cache
      AssetResolver.refresh_cache()
  """

  use GenServer

  require Logger

  alias Lux.Integrations.Hyperliquid.Client

  @cache_ttl_ms 300_000

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Resolves metadata for a given asset name.

  Returns a map with `:asset_id`, `:asset_name`, `:sz_decimals`,
  `:tick_size`, and `:lot_size`. Falls back to fixture data if the
  API is unavailable or the asset is unknown.
  """
  @spec resolve(String.t()) :: map()
  def resolve(asset) when is_binary(asset) do
    case GenServer.whereis(__MODULE__) do
      nil -> resolve_fixture(asset)
      pid -> GenServer.call(pid, {:resolve, asset})
    end
  end

  @doc """
  Returns all known assets from the cache.
  """
  @spec all_assets() :: [map()]
  def all_assets do
    case GenServer.whereis(__MODULE__) do
      nil -> fixtures()
      pid -> GenServer.call(pid, :all_assets)
    end
  end

  @doc """
  Force-refreshes the metadata cache from the API.
  """
  @spec refresh_cache() :: :ok
  def refresh_cache do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.cast(pid, :refresh)
    end
  end

  @doc """
  Returns the asset ID for a given asset name.
  Uses Hyperliquid's L1 index from the exchange meta endpoint.
  """
  @spec asset_id(String.t()) :: integer() | nil
  def asset_id(asset) when is_binary(asset) do
    case resolve(asset) do
      %{asset_id: id} -> id
      _ -> nil
    end
  end

  @doc """
  Returns the size decimals (lot size precision) for a given asset.
  """
  @spec sz_decimals(String.t()) :: integer()
  def sz_decimals(asset) when is_binary(asset) do
    case resolve(asset) do
      %{sz_decimals: sz} when is_integer(sz) -> sz
      _ -> 5
    end
  end

  @doc """
  Returns the tick size for a given asset (default: 0.00001 for 5 decimals).
  """
  @spec tick_size(String.t()) :: float()
  def tick_size(asset) when is_binary(asset) do
    case resolve(asset) do
      %{tick_size: ts} when is_number(ts) -> ts
      _ -> 0.00001
    end
  end

  @impl true
  def init(_opts) do
    state = %{
      assets: %{},
      loaded_at: nil
    }

    # Load fixtures on startup
    fixtures_map = Map.new(fixtures(), fn f -> {f.asset_name, f} end)

    {:ok, %{state | assets: fixtures_map, loaded_at: System.monotonic_time(:millisecond)}}
  end

  @impl true
  def handle_call({:resolve, asset}, _from, state) do
    state = maybe_refresh(state)

    result =
      case Map.get(state.assets, asset) do
        nil -> resolve_fixture(asset)
        meta -> meta
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:all_assets, _from, state) do
    state = maybe_refresh(state)
    {:reply, Map.values(state.assets), state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    case fetch_and_cache(state) do
      {:ok, new_state} ->
        Logger.info("[AssetResolver] Cache refreshed with #{map_size(new_state.assets)} assets")
        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning("[AssetResolver] Cache refresh failed: #{inspect(reason)}, using existing cache")
        {:noreply, state}
    end
  end

  defp maybe_refresh(state) do
    now = System.monotonic_time(:millisecond)

    if is_nil(state.loaded_at) or (now - state.loaded_at) > @cache_ttl_ms do
      case fetch_and_cache(state) do
        {:ok, new_state} -> new_state
        {:error, _reason} -> state
      end
    else
      state
    end
  end

  defp fetch_and_cache(state) do
    case Client.get_market_data() do
      {:ok, data} ->
        assets = parse_universe(data)

        if map_size(assets) == 0 do
          {:error, :empty_universe}
        else
          # Merge with fixtures so known defaults persist
          fixtures_map = Map.new(fixtures(), fn f -> {f.asset_name, f} end)
          merged = Map.merge(fixtures_map, assets)

          {:ok, %{state | assets: merged, loaded_at: System.monotonic_time(:millisecond)}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_universe(data) do
    universe = data["universe"] || []

    universe
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{asset_data, idx}, acc} ->
      name = (asset_data["name"] || "") |> String.upcase()
      if name != "" do
        Map.put(acc, name, build_asset_meta(asset_data, idx))
      else
        acc
      end
    end)
  end

  defp build_asset_meta(asset_data, index) do
    sz_decimals = asset_data["szDecimals"] || 5
    # tick_size = 10^(-sz_decimals) for most Hyperliquid markets
    # but some have custom tick sizes
    tick_size = :math.pow(10, -sz_decimals)
    # lot_size = 10^(-sz_decimals)
    lot_size = :math.pow(10, -sz_decimals)

    %{
      asset_id: index,
      asset_name: asset_data["name"] |> String.upcase(),
      sz_decimals: sz_decimals,
      tick_size: tick_size,
      lot_size: lot_size
    }
  end

  @doc """
  Built-in fixtures for common Hyperliquid assets.
  Used as fallback when the exchange info endpoint is unavailable.
  """
  @spec fixtures() :: [map()]
  def fixtures do
    [
      %{asset_id: 0, asset_name: "BTC", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 1, asset_name: "ETH", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 2, asset_name: "SOL", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 3, asset_name: "ARB", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 4, asset_name: "AVAX", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 5, asset_name: "BNB", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 6, asset_name: "DOGE", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 7, asset_name: "LINK", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 8, asset_name: "MATIC", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 9, asset_name: "OP", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 10, asset_name: "PEPE", sz_decimals: 0, tick_size: 1.0, lot_size: 1.0},
      %{asset_id: 11, asset_name: "SUI", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 12, asset_name: "TON", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 13, asset_name: "TRX", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 14, asset_name: "UNI", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001},
      %{asset_id: 15, asset_name: "XRP", sz_decimals: 5, tick_size: 0.00001, lot_size: 0.00001}
    ]
  end

  @doc false
  @spec resolve_fixture(String.t()) :: map()
  def resolve_fixture(asset) do
    asset_up = String.upcase(asset)

    case Enum.find(fixtures(), &(&1.asset_name == asset_up)) do
      nil ->
        %{
          asset_id: nil,
          asset_name: asset_up,
          sz_decimals: 5,
          tick_size: 0.00001,
          lot_size: 0.00001
        }

      meta ->
        meta
    end
  end
end
