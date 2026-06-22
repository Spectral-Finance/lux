defmodule Lux.Lenses.NftRarityLens do
  @moduledoc """
  Lens for fetching NFT token rarity and trait analysis from Reservoir.

  ## Example

  ```
  alias Lux.Lenses.NftRarityLens

  # Fetch tokens with rarity scores
  NftRarityLens.focus(%{
    collection: "0x8d04a8c79ceb0889bdd12acdf3fa9d207ed3ff63",
    limit: 10,
    sort_by: "rarity"
  })
  ```
  """

  use Lux.Lens,
    name: "NFT Rarity & Traits",
    description: "Fetches token rarity scores and trait analysis",
    url: "https://api.reservoir.tools/tokens/v7",
    method: :get,
    headers: [{"accept", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        collection: %{
          type: :string,
          description: "Collection contract address"
        },
        limit: %{
          type: :integer,
          description: "Number of tokens to return",
          default: 20
        },
        sort_by: %{
          type: :string,
          enum: ["floorAskPrice", "topBidValue", "tokenId", "rarity", "updatedAt"],
          default: "rarity"
        }
      },
      required: ["collection"]
    }

  def add_api_key(lens) do
    case Lux.Config.reservoir_api_key() do
      nil -> lens
      key -> %{lens | headers: lens.headers ++ [{"x-api-key", key}]}
    end
  end

  def before_focus(params) do
    %{
      collection: params.collection,
      limit: Map.get(params, :limit, 20),
      sortBy: Map.get(params, :sort_by, "rarity")
    }
  end

  @impl true
  def after_focus(%{"tokens" => tokens}) when is_list(tokens) do
    analyzed_tokens =
      Enum.map(tokens, fn %{"token" => token} ->
        %{
          token_id: token["tokenId"],
          name: token["name"],
          image: token["image"],
          rarity_rank: token["rarityRank"],
          rarity_score: token["rarityScore"],
          attributes: token["attributes"] |> Enum.map(fn attr -> 
            %{key: attr["key"], value: attr["value"], trait_count: attr["tokenCount"]}
          end)
        }
      end)

    {:ok, %{tokens: analyzed_tokens}}
  end

  @impl true
  def after_focus(%{"message" => message}) do
    {:error, message}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
