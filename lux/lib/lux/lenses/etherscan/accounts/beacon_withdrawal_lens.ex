defmodule Lux.Lenses.Etherscan.BeaconWithdrawal do
  @moduledoc """
  Lens for fetching beacon chain withdrawals made to an Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get beacon chain withdrawals for an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BeaconWithdrawal.focus(%{
    address: "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f"
  })

  # Get beacon chain withdrawals for an address with pagination and block range
  Lux.Lenses.Etherscan.BeaconWithdrawal.focus(%{
    address: "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
    startblock: 17_000_000,
    endblock: 18_000_000,
    page: 1,
    offset: 10,
    sort: "desc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.BeaconWithdrawal",
    description: "Retrieves Ethereum 2.0 beacon chain withdrawal transactions for a specific address",
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
          description: "Target Ethereum address to query for beacon chain withdrawals",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        startblock: %{
          type: :integer,
          description: "Lower block height boundary for filtering withdrawals",
          default: 0
        },
        endblock: %{
          type: :integer,
          description: "Upper block height boundary for filtering withdrawals",
          default: 99_999_999
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of withdrawal records to return per page",
          default: 100
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
    |> Map.put(:action, "txsBeaconWithdrawal")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
