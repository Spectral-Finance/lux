defmodule Lux.Nft.MarketplaceClient do
  @moduledoc """
  Multi-marketplace client and URL builder for OpenSea, Blur, and LooksRare:
  - Collection stats retrieval (floor price, 24h volume, total supply, owner count)
  - Marketplace metadata and fee models (protocol fee & creator royalties)
  """

  @opensea_base "https://api.opensea.io/api/v2"
  @blur_base "https://api.blur.io/v1"
  @looksrare_base "https://api.looksrare.org/api/v2"

  @doc """
  Builds OpenSea collection endpoint URL.
  """
  @spec opensea_collection_url(String.t()) :: String.t()
  def opensea_collection_url(collection_slug) do
    "#{@opensea_base}/collections/#{String.downcase(collection_slug)}"
  end

  @doc """
  Builds OpenSea collection stats endpoint URL.
  """
  @spec opensea_stats_url(String.t()) :: String.t()
  def opensea_stats_url(collection_slug) do
    "#{@opensea_base}/collections/#{String.downcase(collection_slug)}/stats"
  end

  @doc """
  Builds Blur collection listings URL.
  """
  @spec blur_collection_url(String.t()) :: String.t()
  def blur_collection_url(contract_address) do
    "#{@blur_base}/collections/#{String.downcase(contract_address)}"
  end

  @doc """
  Normalizes collection statistics across disparate marketplace payloads.
  """
  @spec normalize_stats(map(), atom()) :: %{
          floor_price_eth: float(),
          volume_24h_eth: float(),
          total_volume_eth: float(),
          total_supply: pos_integer(),
          num_owners: pos_integer(),
          marketplace: atom()
        }
  def normalize_stats(data, marketplace \\ :opensea) do
    case marketplace do
      :opensea ->
        stats = data["total"] || data["stats"] || data

        %{
          floor_price_eth: parse_float(stats["floor_price"]),
          volume_24h_eth: parse_float(stats["one_day_volume"] || stats["volume_24h"]),
          total_volume_eth: parse_float(stats["total_volume"]),
          total_supply: parse_int(stats["total_supply"]),
          num_owners: parse_int(stats["num_owners"]),
          marketplace: :opensea
        }

      :blur ->
        %{
          floor_price_eth: parse_float(data["floorPrice"] || data["floor_price"]),
          volume_24h_eth: parse_float(data["volumeOneDay"] || data["volume_24h"]),
          total_volume_eth: parse_float(data["totalVolume"]),
          total_supply: parse_int(data["totalSupply"]),
          num_owners: parse_int(data["numberOwners"]),
          marketplace: :blur
        }

      _ ->
        %{
          floor_price_eth: parse_float(data["floor_price"]),
          volume_24h_eth: parse_float(data["volume_24h"]),
          total_volume_eth: parse_float(data["total_volume"]),
          total_supply: parse_int(data["total_supply"]),
          num_owners: parse_int(data["num_owners"]),
          marketplace: marketplace
        }
    end
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end
  defp parse_int(_), do: 0
end
