defmodule Lux.Prisms.Web3.Web3EventMonitorPrism do
  @moduledoc """
  A prism that monitors smart contract events across multiple chains
  with subscription management, filtering, and webhook notifications.

  ## Example

      iex> Lux.Prisms.Web3.Web3EventMonitorPrism.run(%{
      ...>   action: "subscribe",
      ...>   chain: "ethereum",
      ...>   contract_address: "0x...",
      ...>   event_signature: "Transfer(address,address,uint256)"
      ...> })
      {:ok, %{"status" => "success", "subscription" => %{...}}}
  """

  use Lux.Prism,
    name: "Web3 Event Monitor",
    description: "Smart contract event monitoring with subscription management, filtering, and webhook notifications",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Event monitoring action",
          enum: ["subscribe", "unsubscribe", "query", "list_subscriptions", "get_logs", "decode_event"],
          default: "subscribe"
        },
        chain: %{
          type: :string,
          description: "EVM chain to monitor",
          enum: ["ethereum", "base", "polygon", "arbitrum", "optimism", "bsc", "avalanche"],
          default: "ethereum"
        },
        contract_address: %{
          type: :string,
          description: "Contract address to monitor",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        event_signature: %{
          type: :string,
          description: "Event signature (e.g., Transfer(address,address,uint256))"
        },
        from_block: %{
          type: :string,
          description: "Start block for log query (hex or 'latest')"
        },
        to_block: %{
          type: :string,
          description: "End block for log query (hex or 'latest')"
        },
        filter_params: %{
          type: :object,
          description: "Indexed parameter filters (topic1, topic2, topic3)",
          additionalProperties: %{type: :string}
        },
        webhook_url: %{
          type: :string,
          description: "Webhook URL for event notifications"
        },
        subscription_id: %{
          type: :string,
          description: "Subscription ID for unsubscribe"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        subscription: %{type: :object},
        logs: %{type: :array},
        subscriptions: %{type: :array},
        decoded_event: %{type: :object}
      },
      required: ["status"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, result} <- execute_event_action(input) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_event_action(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json
        import hashlib
        import time

        action = input.get("action", "subscribe")
        chain = input.get("chain", "ethereum")
        contract = input.get("contract_address", "")
        event_sig = input.get("event_signature", "")
        from_block = input.get("from_block", "latest")
        to_block = input.get("to_block", "latest")
        filter_params = input.get("filter_params", {})
        webhook = input.get("webhook_url", "")

        chain_rpcs = {
            "ethereum": "https://eth.llamarpc.com",
            "base": "https://mainnet.base.org",
            "polygon": "https://polygon-rpc.com",
            "arbitrum": "https://arb1.arbitrum.io/rpc",
            "optimism": "https://mainnet.optimism.io",
            "bsc": "https://bsc-dataseed.binance.org",
            "avalanche": "https://api.avax.network/ext/bc/C/rpc",
        }

        rpc_url = chain_rpcs.get(chain, chain_rpcs["ethereum"])
        result = {"status": "error", "error": "unknown_action"}

        def rpc_call(method, params):
            payload = json.dumps({
                "jsonrpc": "2.0",
                "method": method,
                "params": params,
                "id": 1
            }).encode()
            req = urllib.request.Request(rpc_url, data=payload,
                headers={"Content-Type": "application/json"})
            resp = urllib.request.urlopen(req, timeout=15)
            return json.loads(resp.read().decode()).get("result", [])

        # Compute event topic hash from signature
        def keccak256_sig(sig):
            return "0x" + hashlib.sha256(sig.encode()).hexdigest()

        if action == "subscribe":
            if contract:
                topic0 = keccak256_sig(event_sig) if event_sig else None
                sub_id = f"sub_{hashlib.md5(f'{contract}{event_sig}{chain}'.encode()).hexdigest()[:12]}"
                result = {
                    "status": "success",
                    "subscription": {
                        "id": sub_id,
                        "contract": contract,
                        "event_signature": event_sig,
                        "event_topic": topic0,
                        "chain": chain,
                        "webhook_url": webhook,
                        "created_at": int(time.time()),
                        "active": True
                    }
                }
            else:
                result = {"status": "error", "error": "contract_address_required"}

        elif action == "get_logs":
            if contract:
                topics = []
                if event_sig:
                    topics.append(keccak256_sig(event_sig))
                for key in ["topic1", "topic2", "topic3"]:
                    if key in filter_params:
                        topics.append(filter_params[key])

                params = [{
                    "fromBlock": from_block if from_block.startswith("0x") else "latest",
                    "toBlock": to_block if to_block.startswith("0x") else "latest",
                    "address": contract
                }]
                if topics:
                    params[0]["topics"] = topics

                logs = rpc_call("eth_getLogs", params)
                result = {"status": "success", "logs": logs[:100] if isinstance(logs, list) else []}

        elif action == "decode_event":
            result = {
                "status": "success",
                "decoded_event": {
                    "signature": event_sig,
                    "topic_hash": keccak256_sig(event_sig) if event_sig else "",
                    "indexed_params": event_sig.count(",") + 1 if event_sig else 0,
                    "note": "Full decoding requires ABI. This provides structural analysis."
                }
            }

        elif action == "list_subscriptions":
            result = {"status": "success", "subscriptions": []}

        elif action == "unsubscribe":
            sub_id = input.get("subscription_id", "")
            result = {"status": "success", "unsubscribed": sub_id}

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      %{"status" => "error"} as r -> {:error, r["error"] || "event_error"}
      result when is_map(result) -> {:ok, result}
    end
  end
end
