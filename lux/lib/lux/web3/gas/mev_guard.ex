defmodule Lux.Web3.Gas.MevGuard do
  @moduledoc """
  Maximal Extractable Value (MEV) protection and private transaction routing engine.

  Protects transactions against sandwich attacks, frontrunning, and backrunning by:
  - Assessing trade frontrunning and sandwich vulnerability
  - Routing transactions to zero-leakage private mempools (Flashbots Protect, MEV-Blocker, Eden, etc.)
  - Structuring Flashbots-compatible bundles for builder inclusion without public mempool exposure
  """

  @private_rpc_providers %{
    flashbots: "https://rpc.flashbots.net",
    mev_blocker: "https://rpc.mevblocker.io",
    eden: "https://api.edennetwork.io/v1/rpc",
    secure_rpc: "https://api.securerpc.com/v1"
  }

  @type risk_level :: :low | :medium | :high | :critical

  @type vulnerability_report :: %{
          risk_level: risk_level(),
          slippage_tolerance_pct: float(),
          recommended_route: atom(),
          private_rpc_endpoint: String.t(),
          requires_private_relay: boolean(),
          recommendations: list(String.t())
        }

  @doc """
  Evaluates MEV vulnerability for a transaction based on action type, slippage, and value.
  """
  @spec analyze_vulnerability(map()) :: vulnerability_report()
  def analyze_vulnerability(params) do
    slippage = Map.get(params, :slippage_percentage, 0.5)
    action = Map.get(params, :action_type, :transfer)
    value_eth = Map.get(params, :value_eth, 0.0)

    is_dex_trade = action in [:swap, :dex_trade, :liquidity_add, :liquidity_remove]

    risk_level =
      cond do
        is_dex_trade and (slippage > 2.0 or value_eth > 10.0) -> :critical
        is_dex_trade and (slippage > 1.0 or value_eth > 3.0) -> :high
        is_dex_trade and slippage > 0.5 -> :medium
        value_eth > 20.0 -> :medium
        true -> :low
      end

    requires_private = risk_level in [:medium, :high, :critical]

    recommendations =
      case risk_level do
        :critical ->
          [
            "CRITICAL: Do NOT broadcast to public mempool.",
            "Route exclusively through Flashbots Protect or MEV-Blocker.",
            "Reduce slippage tolerance to <= 0.5%."
          ]

        :high ->
          [
            "High sandwich attack exposure detected.",
            "Utilize private RPC endpoint to avoid searcher arbitrage.",
            "Consider breaking down large volume into smaller chunks."
          ]

        :medium ->
          [
            "Moderate frontrunning risk.",
            "Private RPC recommended for zero-revert guarantees."
          ]

        :low ->
          [
            "Standard transaction. Public mempool or private RPC acceptable."
          ]
      end

    %{
      risk_level: risk_level,
      slippage_tolerance_pct: slippage,
      recommended_route: if(requires_private, do: :flashbots, else: :standard_public),
      private_rpc_endpoint: @private_rpc_providers.flashbots,
      requires_private_relay: requires_private,
      recommendations: recommendations
    }
  end

  @doc """
  Constructs a standard Flashbots / private builder bundle format (`eth_sendBundle`).
  """
  @spec build_private_bundle(list(binary()), non_neg_integer(), non_neg_integer()) :: map()
  def build_private_bundle(signed_txs, target_block, min_timestamp \\ 0) do
    %{
      jsonrpc: "2.0",
      id: 1,
      method: "eth_sendBundle",
      params: [
        %{
          txs: signed_txs,
          blockNumber: "0x" <> Integer.to_string(target_block, 16),
          minTimestamp: min_timestamp
        }
      ]
    }
  end

  @doc """
  Returns the URL of a designated private RPC provider.
  """
  @spec get_provider_rpc(atom()) :: String.t()
  def get_provider_rpc(provider \\ :flashbots) do
    Map.get(@private_rpc_providers, provider, @private_rpc_providers.flashbots)
  end
end
