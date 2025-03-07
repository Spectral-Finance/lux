defmodule Lux.Lenses.Etherscan.DailyBlockRewards do
  @moduledoc """
  Lens for fetching the amount of block rewards distributed to miners daily within a date range from the Etherscan API.

  Note: This endpoint requires an Etherscan Pro API key.

  ## Examples

  ```elixir
  # Get daily block rewards for a date range (default chainid: 1 for Ethereum, sort: "asc")
  Lux.Lenses.Etherscan.DailyBlockRewards.focus(%{
    startdate: "2019-02-01",
    enddate: "2019-02-28"
  })

  # Get daily block rewards for a date range with specific parameters
  Lux.Lenses.Etherscan.DailyBlockRewards.focus(%{
    startdate: "2019-02-01",
    enddate: "2019-02-28",
    sort: "desc",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan Daily Block Rewards API",
    description: "Fetches the amount of block rewards distributed to miners daily",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Chain ID to query (e.g., 1 for Ethereum)",
          default: 1
        },
        startdate: %{
          type: :string,
          description: "The starting date in yyyy-MM-dd format, e.g., 2019-02-01"
        },
        enddate: %{
          type: :string,
          description: "The ending date in yyyy-MM-dd format, e.g., 2019-02-28"
        },
        sort: %{
          type: :string,
          description: "The sorting preference, use 'asc' to sort by ascending and 'desc' to sort by descending",
          enum: ["asc", "desc"],
          default: "asc"
        }
      },
      required: ["startdate", "enddate"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Ensure sort parameter has a default value
    params = case params[:sort] do
      nil -> Map.put(params, :sort, "asc")
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "dailyblockrewards")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        # Process the list of daily block rewards
        processed_results = Enum.map(result, fn item ->
          %{
            date: Map.get(item, "UTCDate", ""),
            block_rewards_eth: Map.get(item, "blockRewards", ""),
            blocks_count: Map.get(item, "blocksCount", ""),
            uncles_inclusion_rewards_eth: Map.get(item, "uncleInclusionRewards", ""),
            uncles_count: Map.get(item, "unclesCount", ""),
            uncle_rewards_eth: Map.get(item, "uncleRewards", ""),
            total_block_rewards_eth: Map.get(item, "totalBlockRewards", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results
        }}
      {:error, %{result: "Invalid API Key"}} ->
        # Handle Pro API key error
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
