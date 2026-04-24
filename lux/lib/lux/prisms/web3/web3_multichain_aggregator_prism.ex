defmodule Lux.Prisms.Web3.Web3MultiChainAggregatorPrism do
  @moduledoc """
  A prism that aggregates data across multiple EVM chains including
  block data, token prices, and protocol metrics.

  ## Example

      iex> Lux.Prisms.Web3.Web3MultiChainAggregatorPrism.run(%{
      ...>   action: "block_info",
      ...>   chains: ["ethereum", "base", "polygon"]
      ...> })
      {:ok, %{"status" => "success", "chain_data" => %{...}}}
  """

  use Lux.Prism,
    name: "Web3 Multi-Chain Data Aggregator",
    description: "Aggregates blockchain data across multiple EVM chains with parallel querying",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Aggregation action",
          enum: ["block_info", "token_price", "address_portfolio", "chain_status"],
          default: "block_info"
        },
        chains: %{
          type: :array,
          description: "Chains to query",
          items: %{type: :string},
          default: ["ethereum", "base", "polygon"]
        },
        address: %{
          type: :string,
          description: "Address for portfolio aggregation",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token_symbol: %{
          type: :string,
          description: "Token symbol for price lookup"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        chain_data: %{type: :object},
        portfolio: %{type: :object}
      },
      required: ["status"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, result} <- execute_aggregation(input) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_aggregation(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json

        action = input.get("action", "block_info")
        chains = input.get("chains", ["ethereum", "base", "polygon"])
        address = input.get("address", "")

        chain_rpcs = {
            "ethereum": {"rpc": "https://eth.llamarpc.com", "chain_id": 1, "symbol": "ETH", "explorer": "https://etherscan.io"},
            "base": {"rpc": "https://mainnet.base.org", "chain_id": 8453, "symbol": "ETH", "explorer": "https://basescan.org"},
            "polygon": {"rpc": "https://polygon-rpc.com", "chain_id": 137, "symbol": "MATIC", "explorer": "https://polygonscan.com"},
            "arbitrum": {"rpc": "https://arb1.arbitrum.io/rpc", "chain_id": 42161, "symbol": "ETH", "explorer": "https://arbiscan.io"},
            "optimism": {"rpc": "https://mainnet.optimism.io", "chain_id": 10, "symbol": "ETH", "explorer": "https://optimistic.etherscan.io"},
            "bsc": {"rpc": "https://bsc-dataseed.binance.org", "chain_id": 56, "symbol": "BNB", "explorer": "https://bscscan.com"},
        }

        def rpc_call(url, method, params):
            payload = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
            req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
            resp = urllib.request.urlopen(req, timeout=15)
            return json.loads(resp.read().decode()).get("result", "0x0")

        result = {"status": "error", "error": "unknown_action"}

        if action == "block_info":
            chain_data = {}
            for ch in chains:
                cfg = chain_rpcs.get(ch)
                if cfg:
                    try:
                        block_num = int(rpc_call(cfg["rpc"], "eth_blockNumber", []), 16)
                        gas_price = int(rpc_call(cfg["rpc"], "eth_gasPrice", []), 16) / 1e9
                        chain_data[ch] = {
                            "latest_block": block_num,
                            "gas_price_gwei": round(gas_price, 2),
                            "chain_id": cfg["chain_id"],
                            "symbol": cfg["symbol"],
                            "explorer": cfg["explorer"]
                        }
                    except Exception as e:
                        chain_data[ch] = {"error": str(e)}
            result = {"status": "success", "chain_data": chain_data}

        elif action == "address_portfolio":
            if address:
                portfolio = {}
                for ch in chains:
                    cfg = chain_rpcs.get(ch)
                    if cfg:
                        try:
                            balance = int(rpc_call(cfg["rpc"], "eth_getBalance", [address, "latest"]), 16)
                            portfolio[ch] = {
                                "balance": balance / 1e18,
                                "symbol": cfg["symbol"],
                                "chain_id": cfg["chain_id"]
                            }
                        except Exception as e:
                            portfolio[ch] = {"error": str(e)}
                result = {"status": "success", "portfolio": portfolio, "address": address}
            else:
                result = {"status": "error", "error": "address_required"}

        elif action == "chain_status":
            status = {}
            for ch, cfg in chain_rpcs.items():
                if ch in chains:
                    try:
                        block = int(rpc_call(cfg["rpc"], "eth_blockNumber", []), 16)
                        status[ch] = {"online": True, "latest_block": block}
                    except:
                        status[ch] = {"online": False}
            result = {"status": "success", "chain_data": status}

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      %{"status" => "error"} as r -> {:error, r["error"] || "aggregation_error"}
      result when is_map(result) -> {:ok, result}
    end
  end
end
