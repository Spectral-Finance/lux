defmodule Lux.Lenses.Etherscan.TxListInternalAddress do
  @moduledoc """
  Lens for fetching internal transactions for a specific Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get internal transactions by address
  Lux.Lenses.Etherscan.TxListInternalAddress.focus(%{
    address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3"
  })

  # With additional parameters
  Lux.Lenses.Etherscan.TxListInternalAddress.focus(%{
    address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
    chainid: 1,
    startblock: 0,
    endblock: 2_702_578,
    page: 1,
    offset: 10,
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TxListInternalAddress",
    description: "Fetches internal transactions for a specific Ethereum address from Etherscan API",
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
          description: "Ethereum address to query for internal transactions (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        startblock: %{
          type: :integer,
          description: "Starting block number to filter transactions from",
          default: 0
        },
        endblock: %{
          type: :integer,
          description: "Ending block number to filter transactions to",
          default: 99_999_999
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results when many transactions exist",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of transactions to return per page (max 10_000)",
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