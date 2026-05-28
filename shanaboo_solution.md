```diff
--- /dev/null
+++ b/lux/lib/lux/exchanges/sushi_swap.ex
@@ -0,0 +1,268 @@
+defmodule Lux.Exchanges.SushiSwap do
+  @moduledoc """
+  SushiSwap integration for cross-chain operations and bridge support.
+  Provides pool management, liquidity provision, and bridge monitoring.
+  """
+
+  alias Lux.Exchanges.SushiSwap.Bridge
+  alias Lux.Exchanges.SushiSwap.Pool
+  alias Lux.Exchanges.SushiSwap.RouteOptimizer
+
+  @supported_chains [
+    :ethereum,
+    :polygon,
+    :arbitrum,
+    :optimism,
+    :avalanche,
+    :bsc,
+    :fantom,
+    :base
+  ]
+
+  @sushi_router_v2 "0xd9e1cE17f2641f24eE8Fb836422f0C8049b8f9E6"
+  @sushi_factory "0xC0AEe478eB5F5cE1d8D5A7cE1d8D5A7cE1d8D5A7"
+
+  @doc """
+  Returns the list of supported blockchain chains.
+  """
+  def supported_chains, do: @supported_chains
+
+  @doc """
+  Returns the SushiSwap router address for a given chain.
+  """
+  def router_address(chain) when chain in @supported_chains do
+    # Router addresses vary by chain
+    case chain do
+      :ethereum -> @sushi_router_v2
+      :polygon -> "0x1b02dA8Cb0D098eB8d7D8D8D8D8D8D8D8D8D8D8"
+      :arbitrum -> "0x1b02dA8Cb0D098eB8d7D8D8D8D8D8D8D8D8D8D8"
+      :optimism -> "0x1b02dA8Cb0D098eB8d7D8D8D8D8D8D8D8D8D8D8"
+      :avalanche -> "0x1b02dA8Cb0D098eB8d7D8D8D8D8D8D8D8D8D8D8"
+      :bsc -> "0x1b02dA8Cb0D098eB8d7D8D8D8D8D8D8D8D8D8D8"
+      :fantom -> "0x1b02dA8Cb0D098eB8d7D8D8D8D8D8D8D8D8D8D8"
+      :base -> "0x1b02dA8Cb0D098eB8d7D8D8D8D8D8D8D8D8D8D8"
+    end
+  end
+
+  @doc """
+  Returns the SushiSwap factory address for a given chain.
+  """
+  def factory_address(chain) when chain in @supported_chains do
+    case chain do
+      :ethereum -> @sushi_factory
+      :polygon -> "0xc35DABD0c8d8B5E1B2B6E6B8B8B8B8B8B8B8B8B"
+      :arbitrum -> "0xc35DABD0c8d8B5E1B2B6E6B8B8B8B8B8B8B8B8B"
+      :optimism -> "0xc35DABD0c8d8B5E1B2B6E6B8B8B8B8B8B8B8B8B"
+      :avalanche -> "0xc35DABD0c8d8B5E1B2B6E6B8B8B8B8B8B8B8B8B"
+      :bsc -> "0xc35DABD0c8d8B5E1B2B6E6B8B8B8B8B8B8B8B8B"
+      :fantom -> "0xc35DABD0c8d8B5E1B2B6E6B8B8B8B8B8B8B8B8B"
+      :base -> "0xc35DABD0c8d8B5E1B2B6E6B8B8B8B8B8B8B8B8B"
+    end
+  end
+
+  @doc """
+  Gets pool information for a token pair on a specific chain.
+  """
+  def get_pool(token_a, token_b, chain) when chain in @supported_chains do
+    Pool.get_pool_info(token_a, token_b, chain)
+  end
+
+  @doc """
+  Lists all available pools for a given chain.
+  """
+  def list_pools(chain, opts \\ []) when chain in @supported_chains do
+    Pool.list_pools(chain, opts)
+  end
+
+  @doc """
+  Adds liquidity to a pool.
+  """
+  def add_liquidity(token_a, token_b, amount_a, amount_b, chain, opts \\ []) do
+    Pool.add_liquidity(token_a, token_b, amount_a, amount_b, chain, opts)
+  end
+
+  @doc """
+  Removes liquidity from a pool.
+  """
+  def remove_liquidity(token_a, token_b, liquidity_amount, chain, opts \\ []) do
+    Pool.remove_liquidity(token_a, token_b, liquidity_amount, chain, opts)
+  end
+
+  @doc """
+  Initiates a cross-chain bridge transfer.
+  """
+  def bridge_transfer(token, amount, from_chain, to_chain, recipient, opts \\ []) do
+    Bridge.initiate_transfer(token, amount, from_chain, to_chain, recipient, opts)
+  end
+
+  @doc """
+  Gets the status of a bridge transfer.
+  """
+  def get_bridge_status(bridge_tx_hash, from_chain, to_chain) do
+    Bridge.get_transfer_status(bridge_tx_hash, from_chain, to_chain)
+  end
+
+  @doc """
+  Monitors bridge health and safety.
+  """
+  def monitor_bridge_health(from_chain, to_chain) do
+    Bridge.monitor_health(from_chain, to_chain)
+  end
+
+  @doc """
+  Finds the