defmodule Lux.Nft.RarityEngine do
  @moduledoc """
  Statistical NFT Rarity calculation and trait frequency analysis engine.
  Computes trait rarity scores: `score = total_supply / trait_count`.
  """

  @type trait :: %{
          trait_type: String.t(),
          value: String.t(),
          count: pos_integer()
        }

  @doc """
  Calculates rarity score for an individual trait based on collection total supply.
  """
  @spec calculate_trait_score(pos_integer(), pos_integer()) :: float()
  def calculate_trait_score(trait_count, total_supply) when trait_count > 0 and total_supply > 0 do
    # Trait score = 1 / (trait_count / total_supply) = total_supply / trait_count
    Float.round(total_supply / trait_count, 2)
  end

  def calculate_trait_score(_, _), do: 0.0

  @doc """
  Computes total statistical rarity score across all traits of an NFT.
  """
  @spec calculate_token_rarity(list(map()), pos_integer()) :: %{
          total_rarity_score: float(),
          trait_scores: list(map()),
          rarity_tier: :legendary | :epic | :rare | :uncommon | :common
        }
  def calculate_token_rarity(traits, total_supply) when is_list(traits) and total_supply > 0 do
    scored_traits =
      Enum.map(traits, fn t ->
        type = t["trait_type"] || t[:trait_type] || "Attribute"
        val = to_string(t["value"] || t[:value] || "")
        count = t["count"] || t[:count] || 1

        score = calculate_trait_score(count, total_supply)
        freq_pct = Float.round(count / total_supply * 100.0, 2)

        %{
          trait_type: type,
          value: val,
          count: count,
          rarity_score: score,
          frequency_pct: freq_pct
        }
      end)

    total_score =
      scored_traits
      |> Enum.map(& &1.rarity_score)
      |> Enum.sum()
      |> Float.round(2)

    tier =
      cond do
        total_score >= 500.0 -> :legendary
        total_score >= 250.0 -> :epic
        total_score >= 100.0 -> :rare
        total_score >= 50.0 -> :uncommon
        true -> :common
      end

    %{
      total_rarity_score: total_score,
      trait_scores: scored_traits,
      rarity_tier: tier
    }
  end

  def calculate_token_rarity(_, _) do
    %{total_rarity_score: 0.0, trait_scores: [], rarity_tier: :common}
  end
end
