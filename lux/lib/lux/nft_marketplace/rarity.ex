defmodule Lux.NFTMarketplace.Rarity do
  @moduledoc """
  Rarity scoring engine for NFTs based on trait frequency.
  """

  alias Lux.NFTMarketplace.Collection

  @doc """
  Calculate rarity score for a single NFT based on its traits and collection stats.

  ## Examples

      iex> Rarity.calculate_score(%{"eyes" => "blue", "hat" => "none"}, collection)
      1250.5
  """
  @spec calculate_score(map(), Collection.t()) :: float()
  def calculate_score(traits, %Collection{} = collection) when is_map(traits) do
    total_supply = max(collection.total_supply, 1)

    traits
    |> Enum.map(fn {trait_type, value} ->
      frequency = get_trait_frequency(collection, trait_type, value)
      1.0 / max(frequency / total_supply, 0.0001)
    end)
    |> Enum.sum()
  end

  @doc """
  Rank a list of NFTs by rarity score.
  """
  @spec rank_nfts(list(map()), Collection.t()) :: list({map(), float()})
  def rank_nfts(nfts, %Collection{} = collection) when is_list(nfts) do
    nfts
    |> Enum.map(fn nft ->
      score = calculate_score(nft["traits"] || %{}, collection)
      {nft, score}
    end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
  end

  @doc """
  Get the frequency of a specific trait value in a collection.
  """
  @spec get_trait_frequency(Collection.t(), String.t(), String.t()) :: non_neg_integer()
  def get_trait_frequency(%Collection{traits: traits}, trait_type, value) do
    case traits do
      %{^trait_type => %{^value => count}} when is_integer(count) and count > 0 ->
        count

      _ ->
        # Default to 1 to avoid division by zero and give unique traits high rarity
        1
    end
  end
end