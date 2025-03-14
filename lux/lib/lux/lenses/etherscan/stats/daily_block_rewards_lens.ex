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
    name: "Etherscan.DailyBlockRewards",
    description: "Provides detailed breakdown of daily mining rewards including block and uncle rewards (requires Pro API key)",
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
          description: "Network identifier (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        startdate: %{
          type: :string,
          description: "Beginning date for reward data in yyyy-MM-dd format"
        },
        enddate: %{
          type: :string,
          description: "Ending date for reward data in yyyy-MM-dd format"
        },
        sort: %{
          type: :string,
          description: "Chronological ordering of results (asc=oldest first, desc=newest first)",
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
    params = params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "dailyblockrewards")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "dailyblockrewards") do
      {:ok, _} -> params
      {:error, message} -> raise ArgumentError, message
    end
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
