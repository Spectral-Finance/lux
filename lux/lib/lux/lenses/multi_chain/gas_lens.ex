defmodule Lux.Lenses.MultiChain.GasLens do
  @moduledoc """
  Lens for fetching gas price oracle data across multiple EVM chains.

  Provides standardized gas price information (safe, proposed, fast)
  from Etherscan's gas oracle endpoint for any supported chain.

  ## Examples

      # Get Ethereum gas prices
      Lux.Lenses.MultiChain.GasLens.focus(%{chainid: 1})

      # Get Polygon gas prices
      Lux.Lenses.MultiChain.GasLens.focus(%{chainid: 137})
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "MultiChain.GasLens",
    description: "Fetches gas price oracle data across multiple EVM chains",
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
          description: "Chain ID (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        }
      }
    }

  def before_focus(params) do
    params
    |> Map.put(:module, "gastracker")
    |> Map.put(:action, "gasoracle")
  end

  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
