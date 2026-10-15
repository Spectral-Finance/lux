defmodule Lux.Web3.GasOptimizer.MEVProtection do
  @moduledoc """
  MEV (Maximal Extractable Value) risk analysis, sandwich attack protection,
  and private relay bundle routing (Flashbots Protect, MEV Blocker).
  """

  @private_relays %{
    ethereum: [
      %{name: "Flashbots Protect", rpc_url: "https://rpc.flashbots.net/fast"},
      %{name: "MEV Blocker", rpc_url: "https://rpc.mevblocker.io"}
    ],
    bsc: [
      %{name: "BSC BloxRoute Private", rpc_url: "https://bsc.rpc.blxrbdn.com"}
    ],
    polygon: [
      %{name: "Polygon Fastlane", rpc_url: "https://fastlane-rpc.polygon.technology"}
    ]
  }

  @dex_selectors [
    "0x38ed1739",
    "0x7ff36ab5",
    "0x18cbafe5",
    "0x5ae401dc",
    "0x04e45aaf"
  ]

  @doc """
  Evaluates MEV / sandwich attack exposure for a transaction and recommends
  private relay routing and slippage bounds.
  """
  @spec analyze_risk(map()) :: map()
  def analyze_risk(tx) when is_map(tx) do
    chain = Map.get(tx, :chain, :ethereum)
    value_wei = Map.get(tx, :value, 0)
    data = to_string(Map.get(tx, :data, "0x"))
    selector = String.slice(String.downcase(data), 0, 10)
    is_dex_swap = selector in @dex_selectors or Map.get(tx, :is_swap, false)

    risk_score = compute_risk_score(is_dex_swap, value_wei, data)
    risk_level = classify_level(risk_score)
    relays = Map.get(@private_relays, chain, [])

    %{
      chain: chain,
      risk_score: risk_score,
      risk_level: risk_level,
      is_dex_swap: is_dex_swap,
      use_private_mempool: risk_level in [:medium, :high],
      recommended_max_slippage_bps: recommended_slippage_bps(risk_level),
      private_relays: relays
    }
  end

  @doc """
  Wraps one or more signed raw transactions into a Flashbots-compatible
  `eth_sendBundle` payload targeting a specific block number.
  """
  @spec build_private_bundle([String.t()], non_neg_integer(), keyword()) :: map()
  def build_private_bundle(raw_txs, target_block, opts \\ [])
      when is_list(raw_txs) and is_integer(target_block) do
    hex_block = "0x" <> String.downcase(Integer.to_string(target_block, 16))

    %{
      "jsonrpc" => "2.0",
      "id" => Keyword.get(opts, :id, 1),
      "method" => "eth_sendBundle",
      "params" => [
        %{
          "txs" => raw_txs,
          "blockNumber" => hex_block,
          "minTimestamp" => Keyword.get(opts, :min_timestamp),
          "maxTimestamp" => Keyword.get(opts, :max_timestamp)
        }
      ]
    }
  end

  defp compute_risk_score(is_dex_swap, value_wei, data) do
    swap_base = if is_dex_swap, do: 0.55, else: 0.10
    eth_value = value_wei / 1.0e18
    size_bonus = min(0.35, eth_value / 50.0 * 0.35)
    calldata_bonus = if byte_size(data) > 138, do: 0.10, else: 0.0
    Float.round(min(1.0, swap_base + size_bonus + calldata_bonus), 2)
  end

  defp classify_level(score) when score >= 0.65, do: :high
  defp classify_level(score) when score >= 0.35, do: :medium
  defp classify_level(_score), do: :low

  defp recommended_slippage_bps(:high), do: 30
  defp recommended_slippage_bps(:medium), do: 50
  defp recommended_slippage_bps(:low), do: 100
end
