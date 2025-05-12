defmodule Lux.Lenses.Etherscan.BlockByTimestamp do
  @moduledoc """
  Lens for fetching the block number that was mined at a certain timestamp from the Etherscan API.

  ## Examples

  ```elixir
  # Get block number by timestamp (default chainid: 1 for Ethereum, closest: "before")
  Lux.Lenses.Etherscan.BlockByTimestamp.focus(%{
    timestamp: 1_578_638_524
  })

  # Get block number by timestamp with specific parameters
  Lux.Lenses.Etherscan.BlockByTimestamp.focus(%{
    timestamp: 1_578_638_524,
    closest: "after",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.BlockByTimestamp",
    description: "Converts a Unix timestamp to the nearest block number mined before or after that time",
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
        timestamp: %{
          type: [:integer, :string],
          description: "Unix timestamp in seconds to find corresponding block for"
        },
        closest: %{
          type: :string,
          description: "Direction to search (before=earlier block, after=later block)",
          enum: ["before", "after"],
          default: "before"
        }
      },
      required: ["timestamp"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Convert timestamp to string if it's an integer
    params = case params[:timestamp] do
      timestamp when is_integer(timestamp) -> Map.put(params, :timestamp, to_string(timestamp))
      _ -> params
    end

    # Ensure closest parameter has a default value
    params = case params[:closest] do
      nil -> Map.put(params, :closest, "before")
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "block")
    |> Map.put(:action, "getblocknobytime")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_binary(result) ->
        # Return a structured response with the block number
        {:ok, %{
          result: %{
            block_number: result
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
