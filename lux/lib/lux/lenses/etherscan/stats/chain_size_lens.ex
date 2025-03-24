defmodule Lux.Lenses.Etherscan.ChainSize do
  @moduledoc """
  Lens for fetching the size of the Ethereum blockchain, in bytes, over a date range from the Etherscan API.

  ## Examples

  ```elixir
  # Get the Ethereum blockchain size for a specific date range with default parameters
  Lux.Lenses.Etherscan.ChainSize.focus(%{
    startdate: "2023-01-01",
    enddate: "2023-01-31"
  })

  # Get the Ethereum blockchain size with all parameters specified
  Lux.Lenses.Etherscan.ChainSize.focus(%{
    startdate: "2023-01-01",
    enddate: "2023-01-31",
    clienttype: "geth",
    syncmode: "default",
    sort: "asc",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.ChainSize",
    description: "Tracks blockchain storage requirements over time for different node configurations",
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
          description: "Beginning date for chain size data in yyyy-MM-dd format"
        },
        enddate: %{
          type: :string,
          description: "Ending date for chain size data in yyyy-MM-dd format"
        },
        clienttype: %{
          type: :string,
          description: "Ethereum client implementation (geth=Go-Ethereum, parity=OpenEthereum)",
          enum: ["geth", "parity"],
          default: "geth"
        },
        syncmode: %{
          type: :string,
          description: "Node synchronization mode (default=fast sync, archive=full historical state)",
          enum: ["default", "archive"],
          default: "default"
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
    # Set default values for optional parameters
    params = params
    |> Map.put_new(:clienttype, "geth")
    |> Map.put_new(:syncmode, "default")
    |> Map.put_new(:sort, "asc")

    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "chainsize")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "chainsize") do
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
        # Process the list of chain size data
        processed_results = Enum.map(result, fn data ->
          %{
            utc_date: Map.get(data, "UTCDate", ""),
            block_number: parse_integer_or_keep(Map.get(data, "blockNumber", "")),
            chain_size_bytes: parse_integer_or_keep(Map.get(data, "chainSize", ""))
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results,
          chain_size: processed_results
        }}
      {:error, %{result: "No data found"}} ->
        # Handle empty results
        {:ok, %{
          result: [],
          chain_size: []
        }}
      {:error, %{result: "This endpoint requires a Pro subscription"}} ->
        # Handle Pro API key errors
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end

  # Helper function to parse string to integer or keep as is
  defp parse_integer_or_keep(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> value
    end
  end
  defp parse_integer_or_keep(value), do: value
end
