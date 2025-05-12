defmodule Lux.Lenses.Etherscan.TxList do
  @moduledoc """
  Lens for fetching normal transactions for an Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get transactions for an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TxList.focus(%{
    address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
  })

  # Get transactions with pagination and block range
  Lux.Lenses.Etherscan.TxList.focus(%{
    address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
    chainid: 1,
    startblock: 0,
    endblock: 99_999_999,
    page: 1,
    offset: 10,
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TxList",
    description: "Retrieves standard Ethereum transactions for an address with filtering and pagination options",
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
        address: %{
          type: :string,
          description: "Target Ethereum address to query transactions for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        startblock: %{
          type: :integer,
          description: "Lower block height boundary for filtering transactions",
          default: 0
        },
        endblock: %{
          type: :integer,
          description: "Upper block height boundary for filtering transactions",
          default: 99_999_999
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of transaction records to return per page",
          default: 10
        },
        sort: %{
          type: :string,
          description: "Chronological ordering of results (asc=oldest first, desc=newest first)",
          enum: ["asc", "desc"],
          default: "asc"
        }
      },
      required: ["address"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "txlist")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
