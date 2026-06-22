defmodule Lux.Prisms.Web3Auth.TokenGatePrism do
  @moduledoc """
  A prism that checks if an address meets a token balance requirement.
  Supports ERC20 and ERC721.
  """
  use Lux.Prism,
    name: "Token Gating",
    description: "Verifies if an address holds a minimum balance of a token",
    input_schema: %{
      type: :object,
      properties: %{
        contract_address: %{type: :string, description: "The token contract address"},
        account: %{type: :string, description: "The address to check"},
        min_balance: %{type: :string, description: "Minimum balance required (as string to avoid precision issues)"},
        rpc_url: %{type: :string, description: "RPC URL to query"}
      },
      required: ["contract_address", "account", "min_balance"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        allowed: %{type: :boolean, description: "Whether the address has enough balance"},
        balance: %{type: :string, description: "The actual balance"},
        error: %{type: :string, description: "Error message if failed"}
      },
      required: ["allowed"]
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    contract_address = Map.get(input, :contract_address) || Map.get(input, "contract_address")
    account = Map.get(input, :account) || Map.get(input, "account")
    min_balance = Map.get(input, :min_balance) || Map.get(input, "min_balance")
    rpc_url = Map.get(input, :rpc_url) || Map.get(input, "rpc_url") || Lux.Integrations.Web3Auth.default_rpc_url()

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- check_balance(contract_address, account, min_balance, rpc_url) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} -> {:error, "Failed to import Web3: #{error}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_balance(contract_address, account, min_balance, rpc_url) do
    result =
      python variables: %{contract: contract_address, account: account, min_balance: min_balance, rpc_url: rpc_url} do
        ~PY"""
        def check(contract, account, min_bal_str, rpc):
            from web3 import Web3
            try:
                w3 = Web3(Web3.HTTPProvider(rpc))
                # ERC20 / ERC721 balance of
                ABI = [{"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"}]
                contract_obj = w3.eth.contract(address=w3.to_checksum_address(contract), abi=ABI)
                
                balance = contract_obj.functions.balanceOf(w3.to_checksum_address(account)).call()
                min_bal = int(min_bal_str)
                
                return {
                    "allowed": balance >= min_bal,
                    "balance": str(balance)
                }
            except Exception as e:
                return {"allowed": False, "error": str(e)}
        result = check(contract, account, min_balance, rpc_url)
        result
        """
      end
    {:ok, result}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
