defmodule Lux.Lenses.Etherscan.EthDailyPrice do
  @moduledoc """
  Lens for fetching the historical price of 1 ETH from the Etherscan API.

  ## Examples

  Fetch Ether historical price for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.EthDailyPrice.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", eth_usd: 1234.56, eth_btc: 0.07_654},
          %{utc_date: "2023-01-02", eth_usd: 1345.67, eth_btc: 0.07_765},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07_876}
        ],
        eth_daily_price: [
          %{utc_date: "2023-01-01", eth_usd: 1234.56, eth_btc: 0.07_654},
          %{utc_date: "2023-01-02", eth_usd: 1345.67, eth_btc: 0.07_765},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07_876}
        ]
      }}

  Fetch Ether historical price for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.EthDailyPrice.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", eth_usd: 1678.90, eth_btc: 0.08_098},
          %{utc_date: "2023-01-04", eth_usd: 1567.89, eth_btc: 0.07_987},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07_876}
        ],
        eth_daily_price: [
          %{utc_date: "2023-01-05", eth_usd: 1678.90, eth_btc: 0.08_098},
          %{utc_date: "2023-01-04", eth_usd: 1567.89, eth_btc: 0.07_987},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07_876}
        ]
      }}
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.EthDailyPrice",
    description: "Provides historical ETH price data in USD and BTC over a specified date range",
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
          description: "Beginning date for price data in yyyy-MM-dd format"
        },
        enddate: %{
          type: :string,
          description: "Ending date for price data in yyyy-MM-dd format"
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
    |> Map.put(:action, "ethdailyprice")
    |> Map.put_new(:sort, "asc")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "ethdailyprice") do
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
        price_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              eth_usd: parse_float_or_keep(item["value"]),
              eth_btc: parse_float_or_keep(item["ethBtc"])
            }
          end)

        {:ok, %{result: price_data, eth_daily_price: price_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], eth_daily_price: []}}

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
