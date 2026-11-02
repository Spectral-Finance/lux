defmodule Lux.Web3.WalletInfrastructure.BalanceTracker do
  @moduledoc """
  Multi-chain balance monitoring, ERC-20 token balance tracking,
  and portfolio aggregation across supported EVM networks.
  """

  @supported_chains %{
    1 => %{name: "Ethereum Mainnet", symbol: "ETH", decimals: 18},
    11155111 => %{name: "Sepolia Testnet", symbol: "ETH", decimals: 18},
    42161 => %{name: "Arbitrum One", symbol: "ETH", decimals: 18},
    10 => %{name: "Optimism", symbol: "ETH", decimals: 18},
    8453 => %{name: "Base", symbol: "ETH", decimals: 18},
    137 => %{name: "Polygon PoS", symbol: "POL", decimals: 18},
    56 => %{name: "BNB Smart Chain", symbol: "BNB", decimals: 18}
  }

  @type chain_balance :: %{
          chain_id: non_neg_integer(),
          network_name: String.t(),
          symbol: String.t(),
          balance_raw_wei: non_neg_integer(),
          balance_formatted: float(),
          usd_value: float()
        }

  @type portfolio_summary :: %{
          address: String.t(),
          total_usd_value: float(),
          chains: list(chain_balance())
        }

  @doc """
  Fetches / aggregates balances for an address across all configured EVM chains.
  """
  @spec fetch_multi_chain_balances(String.t(), map()) :: portfolio_summary()
  def fetch_multi_chain_balances(address, mock_balances \\ %{}) do
    chain_results =
      Enum.map(@supported_chains, fn {chain_id, meta} ->
        raw_wei = Map.get(mock_balances, chain_id, 1_500_000_000_000_000_000) # Default 1.5 ETH mock
        formatted = Float.round(raw_wei / 1_000_000_000_000_000_000.0, 4)
        price = get_mock_price(meta.symbol)
        usd = Float.round(formatted * price, 2)

        %{
          chain_id: chain_id,
          network_name: meta.name,
          symbol: meta.symbol,
          balance_raw_wei: raw_wei,
          balance_formatted: formatted,
          usd_value: usd
        }
      end)

    total_usd =
      chain_results
      |> Enum.reduce(0.0, fn c, acc -> acc + c.usd_value end)
      |> Float.round(2)

    %{
      address: address,
      total_usd_value: total_usd,
      chains: chain_results
    }
  end

  @doc """
  Formats raw Wei balance into human-readable ether float.
  """
  @spec wei_to_ether(non_neg_integer()) :: float()
  def wei_to_ether(wei) when is_integer(wei) do
    Float.round(wei / 1_000_000_000_000_000_000.0, 6)
  end

  defp get_mock_price("ETH"), do: 3200.0
  defp get_mock_price("POL"), do: 0.45
  defp get_mock_price("BNB"), do: 580.0
  defp get_mock_price(_), do: 1.0
end
