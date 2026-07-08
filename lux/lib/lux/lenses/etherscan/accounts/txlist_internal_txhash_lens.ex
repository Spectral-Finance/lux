defmodule Lux.Lenses.Etherscan.TxListInternalTxhash do
  @moduledoc """
  Lens for fetching internal transactions for a specific transaction hash from the Etherscan API.

  ## Examples

  ```elixir
  # Get internal transactions by transaction hash
  Lux.Lenses.Etherscan.TxListInternalTxhash.focus(%{
    txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
  })

  # With additional parameters
  Lux.Lenses.Etherscan.TxListInternalTxhash.focus(%{
    txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TxListInternalTxhash",
    description: "Fetches internal transactions for a specific transaction hash from Etherscan API",
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
        txhash: %{
          type: :string,
          description: "Transaction hash to query for internal transactions (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{64}$"
        }
      },
      required: ["txhash"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "txlistinternal")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end 