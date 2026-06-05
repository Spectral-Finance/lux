defmodule Lux.Integrations.NFTMarketplace do
  @moduledoc "NFT marketplace data aggregation for OpenSea, Blur, and X2Y2."
  @opensea_url "https://api.opensea.io/api/v2"
  @blur_url "https://core-api.blur.io/v1"
  def opensea_collection(slug), do: get(@opensea_url, "/collections/#{slug}", %{}, "X-API-KEY")
  def opensea_nfts(addr, limit \\ 50), do: get(@opensea_url, "/chain/ethereum/account/#{addr}/nfts", %{limit: limit}, "X-API-KEY")
  def blur_collections, do: get(@blur_url, "/collections", %{}, nil)
  defp get(base, path, params, hdr) do
    url = base <> path <> (if params != %{}, do: "?" <> URI.encode_query(params), else: "")
    hs = [{"Content-Type", "application/json"}]
    hs = if hdr, do: [{hdr, api_key()} | hs], else: hs
    case Req.get(url, headers: hs) do
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, e} -> {:error, inspect(e)}
    end
  end
  defp api_key, do: Application.get_env(:lux, Lux.Integrations.NFTMarketplace)[:opensea_api_key]
end