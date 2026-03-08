defmodule Lux.Prisms.Web3.Chain.MultiChainQuery do
  @moduledoc """
  Prism for querying data across multiple chains simultaneously.

  Aggregates balance, block, and transaction data across all supported chains.
  """

  use Lux.Prism,
    name: "Multi-Chain Query",
    description: "Query blockchain data across multiple EVM chains",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["multi_balance", "multi_block", "chain_compare"]},
        address: %{type: :string},
        chains: %{type: :array, description: "List of chain keys"}
      },
      required: ["action"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Web3.Chain.RpcClient

  @chain_rpcs %{
    ethereum: "https://eth.llamarpc.com",
    polygon: "https://polygon-rpc.com",
    arbitrum: "https://arb1.arbitrum.io/rpc",
    optimism: "https://mainnet.optimism.io",
    base: "https://mainnet.base.org",
    bsc: "https://bsc-dataseed.binance.org",
    avalanche: "https://api.avax.network/ext/bc/C/rpc"
  }

  @chain_symbols %{
    ethereum: "ETH", polygon: "MATIC", arbitrum: "ETH",
    optimism: "ETH", base: "ETH", bsc: "BNB", avalanche: "AVAX"
  }

  @impl true
  def handler(params, _opts) do
    action = params[:action] || params["action"]
    plug = params[:plug]

    case action do
      "multi_balance" -> multi_balance(params, plug)
      "multi_block" -> multi_block(params, plug)
      "chain_compare" -> chain_compare(params, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp multi_balance(params, plug) do
    address = params[:address] || params["address"]
    chains = normalize_chains(params[:chains] || params["chains"])

    results = Enum.map(chains, fn chain ->
      rpc = @chain_rpcs[chain]
      opts = [rpc_url: rpc] ++ if(plug, do: [plug: plug], else: [])

      case RpcClient.call("eth_getBalance", [address, "latest"], opts) do
        {:ok, hex} ->
          wei = parse_hex(hex)
          %{chain: chain, symbol: @chain_symbols[chain], balance_wei: wei,
            balance: wei / 1.0e18}

        {:error, reason} ->
          %{chain: chain, error: inspect(reason)}
      end
    end)

    total_usd = nil  # Would need price oracle
    {:ok, %{address: address, balances: results, total_usd: total_usd}}
  end

  defp multi_block(params, plug) do
    chains = normalize_chains(params[:chains] || params["chains"])

    results = Enum.map(chains, fn chain ->
      rpc = @chain_rpcs[chain]
      opts = [rpc_url: rpc] ++ if(plug, do: [plug: plug], else: [])

      case RpcClient.call("eth_blockNumber", [], opts) do
        {:ok, hex} ->
          %{chain: chain, block_number: parse_hex(hex)}

        {:error, reason} ->
          %{chain: chain, error: inspect(reason)}
      end
    end)

    {:ok, %{blocks: results}}
  end

  defp chain_compare(params, plug) do
    chains = normalize_chains(params[:chains] || params["chains"])

    results = Enum.map(chains, fn chain ->
      rpc = @chain_rpcs[chain]
      opts = [rpc_url: rpc] ++ if(plug, do: [plug: plug], else: [])

      block_num = case RpcClient.call("eth_blockNumber", [], opts) do
        {:ok, hex} -> parse_hex(hex)
        _ -> nil
      end

      gas_price = case RpcClient.call("eth_gasPrice", [], opts) do
        {:ok, hex} -> parse_hex(hex)
        _ -> nil
      end

      %{
        chain: chain,
        block_number: block_num,
        gas_price_gwei: if(gas_price, do: Float.round(gas_price / 1.0e9, 2)),
        symbol: @chain_symbols[chain]
      }
    end)

    {:ok, %{chains: results}}
  end

  defp normalize_chains(nil), do: Map.keys(@chain_rpcs)
  defp normalize_chains(chains) when is_list(chains) do
    Enum.map(chains, fn
      c when is_atom(c) -> c
      c when is_binary(c) -> String.to_existing_atom(c)
    end)
    |> Enum.filter(&Map.has_key?(@chain_rpcs, &1))
  end

  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(n) when is_integer(n), do: n
  defp parse_hex(_), do: 0
end
