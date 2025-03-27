defmodule Lux.Lenses.Etherscan.DailyAvgGasLimit do
  @moduledoc """
  Lens for fetching the historical daily average gas limit of the Ethereum network from the Etherscan API.

  ## Examples

  ```elixir
  # Get daily average gas limit for a specific date range with ascending sort (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.DailyAvgGasLimit.focus(%{
    startdate: "2023-01-01",
    enddate: "2023-01-31",
    sort: "asc"
  })

  # Get daily average gas limit for a specific date range with descending sort on a specific chain
  Lux.Lenses.Etherscan.DailyAvgGasLimit.focus(%{
    startdate: "2023-01-01",
    enddate: "2023-01-31",
    sort: "desc",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.DailyAvgGasLimit",
    description: "Retrieves historical network capacity data showing daily average block gas limits",
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
          description: "Beginning date for gas limit data in yyyy-MM-dd format"
        },
        enddate: %{
          type: :string,
          description: "Ending date for gas limit data in yyyy-MM-dd format"
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
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "dailyavggaslimit")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "dailyavggaslimit") do
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
        # Process the list of daily gas limit data
        processed_results = Enum.map(result, fn data ->
          %{
            utc_date: Map.get(data, "UTCDate", ""),
            gas_limit: parse_float_or_keep(Map.get(data, "gasLimit", ""))
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results,
          daily_avg_gas_limit: processed_results
        }}
      {:error, %{result: "No data found"}} ->
        # Handle empty results
        {:ok, %{
          result: [],
          daily_avg_gas_limit: []
        }}
      {:error, %{result: "This endpoint requires a Pro subscription"}} ->
        # Handle Pro API key errors
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end

  # Helper function to parse string to float or keep as is
  defp parse_float_or_keep(value) when is_binary(value) do
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> value
    end
  end
  defp parse_float_or_keep(value), do: value
end
