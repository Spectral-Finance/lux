defmodule Lux.Lenses.Reservoir.RarityLens do
  @moduledoc """
  A lens for fetching NFT rarity and trait analysis from Reservoir.
  """

  alias Lux.Integrations.Reservoir
  require Logger

  use Lux.Lens,
    name: "NFT Rarity",
    description: "Fetches tokens sorted by rarity and their trait analysis",
    url: "#{Reservoir.base_url()}/tokens/v7",
    method: :get,
    headers: Reservoir.headers(),
    auth: Reservoir.auth(),
    schema: %{
      type: :object,
      properties: %{
        collection: %{
          type: :string,
          description: "Collection contract address"
        },
        limit: %{
          type: :integer,
          description: "Number of tokens to fetch"
        }
      },
      required: ["collection"]
    }

  @impl true
  def before_focus(%{collection: collection} = params) do
    limit = Map.get(params, :limit, 5)
    {:ok, %{query: %{collection: collection, limit: limit, sortBy: "rarity"}}}
  end

  @impl true
  def after_focus(%{"tokens" => tokens} = _response) do
    Logger.info("Successfully fetched #{length(tokens)} tokens for rarity analysis")
    {:ok, %{tokens: Enum.map(tokens, &transform_token/1)}}
  end

  def after_focus(response) do
    Logger.error("Failed to fetch rarity data: #{inspect(response)}")
    {:error, response}
  end

  defp transform_token(token_entry) do
    token = token_entry["token"]
    %{
      token_id: token["tokenId"],
      name: token["name"],
      rarity_rank: token["rarityRank"],
      rarity_score: token["rarityScore"],
      attributes: token["attributes"]
    }
  end
end
