defmodule Lux.Lenses.Etherscan.DailyTxCount do
  @moduledoc """
  Lens for fetching the number of transactions performed on the Ethereum blockchain per day from the Etherscan API.

  ## Examples

  Fetch daily transaction count for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.DailyTxCount.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", tx_count: 1234567},
          %{utc_date: "2023-01-02", tx_count: 1345678},
          %{utc_date: "2023-01-03", tx_count: 1456789}
        ],
        daily_tx_count: [
          %{utc_date: "2023-01-01", tx_count: 1234567},
          %{utc_date: "2023-01-02", tx_count: 1345678},
          %{utc_date: "2023-01-03", tx_count: 1456789}
        ]
      }}

  Fetch daily transaction count for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.DailyTxCount.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", tx_count: 1678901},
          %{utc_date: "2023-01-04", tx_count: 1567890},
          %{utc_date: "2023-01-03", tx_count: 1456789}
        ],
        daily_tx_count: [
          %{utc_date: "2023-01-05", tx_count: 1678901},
          %{utc_date: "2023-01-04", tx_count: 1567890},
          %{utc_date: "2023-01-03", tx_count: 1456789}
        ]
      }}
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: [
      chainid: [type: :integer, required: true],
      startdate: [type: :string, required: true],
      enddate: [type: :string, required: true],
      sort: [type: :string, required: false]
    ]

  @doc """
  Prepares parameters for the API request.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "dailytx")
    |> Map.put_new(:sort, "asc")
  end

  @doc """
  Processes the API response.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        tx_count_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              tx_count: parse_integer_or_keep(item["transactionCount"])
            }
          end)

        {:ok, %{result: tx_count_data, daily_tx_count: tx_count_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], daily_tx_count: []}}

      {:error, %{result: "This endpoint requires a Pro subscription"}} ->
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}

      other ->
        other
    end
  end

  defp parse_integer_or_keep(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> value
    end
  end

  defp parse_integer_or_keep(value), do: value
end
