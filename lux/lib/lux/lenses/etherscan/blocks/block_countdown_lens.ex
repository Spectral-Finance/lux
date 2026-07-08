defmodule Lux.Lenses.Etherscan.BlockCountdown do
  @moduledoc """
  Lens for fetching the estimated time remaining, in seconds, until a certain block is mined from the Etherscan API.

  ## Examples

  ```elixir
  # Get estimated time remaining for a future block (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BlockCountdown.focus(%{
    blockno: 16701588
  })

  # Get estimated time remaining for a future block on a specific chain
  Lux.Lenses.Etherscan.BlockCountdown.focus(%{
    blockno: 16701588,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.BlockCountdown",
    description: "Estimates time remaining until a future block is mined based on current network conditions",
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
        blockno: %{
          type: [:integer, :string],
          description: "Target future block number to calculate time estimation for"
        }
      },
      required: ["blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Convert blockno to string if it's an integer
    params = case params[:blockno] do
      blockno when is_integer(blockno) -> Map.put(params, :blockno, to_string(blockno))
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "block")
    |> Map.put(:action, "getblockcountdown")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Extract the relevant information
        current_block = Map.get(result, "CurrentBlock")
        countdown_block = Map.get(result, "CountdownBlock")
        remaining_blocks = Map.get(result, "RemainingBlock")
        estimated_time_in_sec = Map.get(result, "EstimateTimeInSec")

        # Return a structured response
        {:ok, %{
          result: %{
            current_block: current_block,
            countdown_block: countdown_block,
            remaining_blocks: remaining_blocks,
            estimated_time_in_sec: estimated_time_in_sec
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
