defmodule Lux.Lenses.MultiChain.BalanceLens do
  @moduledoc """
  Lens for fetching native token balances across multiple EVM chains.

  Wraps the Etherscan v2 API to provide unified balance queries with
  automatic chain routing via `chainid`.

  ## Examples

      # Get ETH balance on Ethereum
      Lux.Lenses.MultiChain.BalanceLens.focus(%{
        address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        chainid: 1
      })

      # Get MATIC balance on Polygon
      Lux.Lenses.MultiChain.BalanceLens.focus(%{
        address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        chainid: 137
      })
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "MultiChain.BalanceLens",
    description: "Fetches native token balances across multiple EVM chains",
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
        },
        address: %{
          type: :string,
          description: "Address to check balance for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        tag: %{
          type: :string,
          description: "Block tag (latest, earliest, pending)",
          enum: ["latest", "earliest", "pending"],
          default: "latest"
        }
      },
      required: ["address"]
    }

  def before_focus(params) do
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "balance")
  end

  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: balance}} ->
        {:ok, %{
          balance_wei: balance,
          balance_eth: wei_to_eth(balance)
        }}

      error ->
        error
    end
  end

  defp wei_to_eth(wei) when is_binary(wei) do
    case Integer.parse(wei) do
      {val, _} -> val / 1.0e18
      :error -> 0.0
    end
  end
end
