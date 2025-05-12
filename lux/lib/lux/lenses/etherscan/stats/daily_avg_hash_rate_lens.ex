defmodule Lux.Lenses.Etherscan.DailyAvgHashRate do
  @moduledoc """
  Lens for fetching the daily average network hash rate from the Etherscan API.

  ## Examples

  Fetch daily average hash rate for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.DailyAvgHashRate.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", hash_rate_ghs: 1_234_567.89},
          %{utc_date: "2023-01-02", hash_rate_ghs: 1_345_678.90},
          %{utc_date: "2023-01-03", hash_rate_ghs: 1_456_789.01}
        ],
        daily_avg_hash_rate: [
          %{utc_date: "2023-01-01", hash_rate_ghs: 1_234_567.89},
          %{utc_date: "2023-01-02", hash_rate_ghs: 1_345_678.90},
          %{utc_date: "2023-01-03", hash_rate_ghs: 1_456_789.01}
        ]
      }}

  Fetch daily average hash rate for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.DailyAvgHashRate.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", hash_rate_ghs: 1_678_901.23},
          %{utc_date: "2023-01-04", hash_rate_ghs: 1_567_890.12},
          %{utc_date: "2023-01-03", hash_rate_ghs: 1_456_789.01}
        ],
        daily_avg_hash_rate: [
          %{utc_date: "2023-01-05", hash_rate_ghs: 1_678_901.23},
          %{utc_date: "2023-01-04", hash_rate_ghs: 1_567_890.12},
          %{utc_date: "2023-01-03", hash_rate_ghs: 1_456_789.01}
        ]
      }}
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.DailyAvgHashRate",
    description: "Tracks historical mining/validation power of the network through daily average hash rates",
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
          description: "Beginning date for hash rate data in yyyy-MM-dd format"
        },
        enddate: %{
          type: :string,
          description: "Ending date for hash rate data in yyyy-MM-dd format"
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
    |> Map.put(:action, "dailyavghashrate")
    |> Map.put_new(:sort, "asc")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "dailyavghashrate") do
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
        hash_rate_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              hash_rate_ghs: parse_float_or_keep(item["networkHashRate"])
            }
          end)

        {:ok, %{result: hash_rate_data, daily_avg_hash_rate: hash_rate_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], daily_avg_hash_rate: []}}

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
