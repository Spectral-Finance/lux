defmodule Lux.Lenses.Etherscan.EthPrice do
  @moduledoc """
  Lens for fetching the latest price of 1 ETH from the Etherscan API.

  ## Examples

  ```elixir
  # Get the latest ETH price (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.EthPrice.focus(%{})

  # Get the latest ETH price for a specific chain
  Lux.Lenses.Etherscan.EthPrice.focus(%{
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.EthPrice",
    description: "Retrieves current real-time ETH price in USD and BTC with timestamps",
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
        }
      },
      required: []
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "ethprice")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Process the result map and convert string values to numbers
        processed_result = %{
          eth_btc: parse_float_or_keep(Map.get(result, "ethbtc", "")),
          eth_btc_timestamp: parse_integer_or_keep(Map.get(result, "ethbtc_timestamp", "")),
          eth_usd: parse_float_or_keep(Map.get(result, "ethusd", "")),
          eth_usd_timestamp: parse_integer_or_keep(Map.get(result, "ethusd_timestamp", ""))
        }

        # Return a structured response
        {:ok, %{
          result: processed_result,
          eth_price: processed_result
        }}
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

  # Helper function to parse string to integer or keep as is
  defp parse_integer_or_keep(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> value
    end
  end
  defp parse_integer_or_keep(value), do: value
end
