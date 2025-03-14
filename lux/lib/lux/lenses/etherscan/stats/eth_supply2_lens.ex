defmodule Lux.Lenses.Etherscan.EthSupply2 do
  @moduledoc """
  Lens for fetching the current amount of Ether in circulation from the Etherscan API.
  This includes ETH2 Staking rewards, EIP1559 burnt fees, and total withdrawn ETH from the beacon chain.

  ## Examples

  ```elixir
  # Get the current ETH supply with additional details (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.EthSupply2.focus(%{})

  # Get the current ETH supply with additional details for a specific chain
  Lux.Lenses.Etherscan.EthSupply2.focus(%{
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.EthSupply2",
    description: "Provides comprehensive ETH supply metrics including staking rewards, burnt fees, and withdrawals",
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
    |> Map.put(:action, "ethsupply2")
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
          eth_supply: parse_number_or_keep(Map.get(result, "EthSupply", "")),
          eth2_staking: parse_number_or_keep(Map.get(result, "Eth2Staking", "")),
          burnt_fees: parse_number_or_keep(Map.get(result, "BurntFees", "")),
          withdrawn_eth: parse_number_or_keep(Map.get(result, "WithdrawnTotal", ""))
        }

        # Return a structured response
        {:ok, %{
          result: processed_result,
          eth_supply_details: processed_result
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end

  # Helper function to parse string to number or keep as is
  defp parse_number_or_keep(value) when is_binary(value) do
    # Try to parse as float first, which will handle both integer and float values
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> value
    end
  end
  defp parse_number_or_keep(value), do: value
end
