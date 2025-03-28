defmodule Lux.Lenses.Etherscan.DailyNetworkUtilization do
  @moduledoc """
  Lens for fetching the daily network utilization (gas used / gas limit) from the Etherscan API.

  ## Examples

  Fetch daily network utilization for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.DailyNetworkUtilization.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", utilization_percentage: 45.67},
          %{utc_date: "2023-01-02", utilization_percentage: 52.34},
          %{utc_date: "2023-01-03", utilization_percentage: 48.91}
        ],
        daily_network_utilization: [
          %{utc_date: "2023-01-01", utilization_percentage: 45.67},
          %{utc_date: "2023-01-02", utilization_percentage: 52.34},
          %{utc_date: "2023-01-03", utilization_percentage: 48.91}
        ]
      }}

  Fetch daily network utilization for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.DailyNetworkUtilization.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", utilization_percentage: 51.23},
          %{utc_date: "2023-01-04", utilization_percentage: 49.78},
          %{utc_date: "2023-01-03", utilization_percentage: 48.91}
        ],
        daily_network_utilization: [
          %{utc_date: "2023-01-05", utilization_percentage: 51.23},
          %{utc_date: "2023-01-04", utilization_percentage: 49.78},
          %{utc_date: "2023-01-03", utilization_percentage: 48.91}
        ]
      }}
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.DailyNetworkUtilization",
    description: "Measures blockchain congestion levels through daily network capacity utilization percentages",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
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
          description: "Beginning date for utilization data in yyyy-MM-dd format"
        },
        enddate: %{
          type: :string,
          description: "Ending date for utilization data in yyyy-MM-dd format"
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
  Prepares parameters for the API request.
  """
  def before_focus(params) do
    params = params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "dailynetworkutilization")
    |> Map.put_new(:sort, "asc")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "dailynetworkutilization") do
      {:ok, _} -> params
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Processes the API response.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        network_utilization_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              utilization_percentage: parse_float_or_keep(item["utilizationPercentage"])
            }
          end)

        {:ok, %{result: network_utilization_data, daily_network_utilization: network_utilization_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], daily_network_utilization: []}}

      {:error, %{result: "This endpoint requires a Pro subscription"}} ->
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}

      other ->
        other
    end
  end

  defp parse_float_or_keep(value) when is_binary(value) do
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> value
    end
  end

  defp parse_float_or_keep(value), do: value
end
