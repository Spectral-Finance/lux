defmodule Lux.Lenses.Etherscan.GasOracle do
  @moduledoc """
  Lens for fetching the current Safe, Proposed and Fast gas prices from the Etherscan API.

  Post EIP-1559 changes:
  - Safe/Proposed/Fast gas price recommendations are now modeled as Priority Fees.
  - Includes suggestBaseFee, the baseFee of the next pending block.
  - Includes gasUsedRatio, to estimate how busy the network is.

  ## Examples

  ```elixir
  # Get current gas prices (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.GasOracle.focus(%{})

  # Get current gas prices on a specific chain
  Lux.Lenses.Etherscan.GasOracle.focus(%{
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.GasOracle",
    description: "Provides real-time gas price recommendations (slow/average/fast) and network congestion metrics",
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
    |> Map.put(:module, "gastracker")
    |> Map.put(:action, "gasoracle")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Convert string values to appropriate types
        processed_result = %{
          safe_gas_price: parse_float_or_keep(Map.get(result, "SafeGasPrice", "")),
          propose_gas_price: parse_float_or_keep(Map.get(result, "ProposeGasPrice", "")),
          fast_gas_price: parse_float_or_keep(Map.get(result, "FastGasPrice", "")),
          suggest_base_fee: parse_float_or_keep(Map.get(result, "suggestBaseFee", "")),
          gas_used_ratio: Map.get(result, "gasUsedRatio", ""),
          last_block: parse_integer_or_keep(Map.get(result, "LastBlock", ""))
        }

        # Return a structured response
        {:ok, %{
          result: processed_result,
          gas_oracle: processed_result
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
