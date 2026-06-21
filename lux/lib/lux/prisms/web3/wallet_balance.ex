defmodule Lux.Prisms.Web3.WalletBalance do
  @moduledoc """
  A prism to check the balance of a managed Web3 wallet.
  """
  use Lux.Prism,
    name: "Web3 Wallet Balance",
    description: "Checks the balance of an internally managed wallet via RPC.",
    input_schema: %{
      type: :object,
      properties: %{
        name: %{
          type: :string,
          description: "Internal name/alias for the wallet."
        },
        rpc_url: %{
          type: :string,
          description: "HTTP RPC URL."
        }
      },
      required: ["name", "rpc_url"]
    }

  alias Lux.Integrations.Web3.WalletManager

  def handler(params, _context) do
    case WalletManager.get_balance(params.name, params.rpc_url) do
      {:ok, balance} -> {:ok, %{balance: balance}}
      {:error, err} -> {:error, "Failed to fetch balance: #{inspect(err)}"}
    end
  end
end
