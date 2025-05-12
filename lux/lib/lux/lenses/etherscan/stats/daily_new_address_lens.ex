defmodule Lux.Lenses.Etherscan.DailyNewAddress do
  @moduledoc """
  Lens for fetching the number of new Ethereum addresses created per day from the Etherscan API.

  ## Examples

  Fetch daily new address counts for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.DailyNewAddress.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", new_address_count: 12_345},
          %{utc_date: "2023-01-02", new_address_count: 23_456},
          %{utc_date: "2023-01-03", new_address_count: 34_567}
        ],
        daily_new_address: [
          %{utc_date: "2023-01-01", new_address_count: 12_345},
          %{utc_date: "2023-01-02", new_address_count: 23_456},
          %{utc_date: "2023-01-03", new_address_count: 34_567}
        ]
      }}

  Fetch daily new address counts for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.DailyNewAddress.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", new_address_count: 56_789},
          %{utc_date: "2023-01-04", new_address_count: 45_678},
          %{utc_date: "2023-01-03", new_address_count: 34_567}
        ],
        daily_new_address: [
          %{utc_date: "2023-01-05", new_address_count: 56_789},
          %{utc_date: "2023-01-04", new_address_count: 45_678},
          %{utc_date: "2023-01-03", new_address_count: 34_567}
        ]
      }}
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.DailyNewAddress",
    description: "Tracks blockchain adoption metrics through daily count of newly created addresses",
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
          description: "Beginning date for address creation data in yyyy-MM-dd format"
        },
        enddate: %{
          type: :string,
          description: "Ending date for address creation data in yyyy-MM-dd format"
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
    |> Map.put(:action, "dailynewaddress")
    |> Map.put_new(:sort, "asc")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "dailynewaddress") do
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
        new_address_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              new_address_count: parse_integer_or_keep(item["newAddressCount"])
            }
          end)

        {:ok, %{result: new_address_data, daily_new_address: new_address_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], daily_new_address: []}}

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
