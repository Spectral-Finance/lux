defmodule Lux.Lenses.Etherscan.GasEstimate do
  @moduledoc """
  Lens for fetching the estimated confirmation time for a transaction based on gas price from the Etherscan API.

  ## Examples

  ```elixir
  # Get estimated confirmation time for a transaction with a specific gas price (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.GasEstimate.focus(%{
    gasprice: 2_000_000_000
  })

  # Get estimated confirmation time for a transaction with a specific gas price on a specific chain
  Lux.Lenses.Etherscan.GasEstimate.focus(%{
    gasprice: 2_000_000_000,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.GasEstimate",
    description: "Predicts transaction confirmation time in seconds based on a specified gas price",
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
        gasprice: %{
          type: :integer,
          description: "Transaction gas price in wei to estimate confirmation time for"
        }
      },
      required: ["gasprice"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "gastracker")
    |> Map.put(:action, "gasestimate")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} ->
        # Convert the result to an integer if it's a string containing a number
        result =
          case Integer.parse(result) do
            {int_value, _} -> int_value
            :error -> result
          end

        # Return a structured response
        {:ok, %{
          result: result,
          estimated_seconds: result
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
