defmodule Lux.Lenses.Web3.BalanceLens do
  @moduledoc """
  A Lux Lens for querying wallet balances across multiple EVM chains.
  Returns cached balance data from the BalanceMonitor.
  """

  use Lux.Lens,
    name: "Web3 Balance Query",
    description: "Queries cached wallet balances across monitored EVM chains",
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "The wallet address to query balances for"
        },
        chain_id: %{
          type: :integer,
          description: "Optional specific chain ID to query (returns all chains if omitted)"
        }
      },
      required: ["address"]
    }

  @impl true
  def focus(%{address: address} = params, _opts) do
    case Map.get(params, :chain_id) do
      nil ->
        case Lux.Web3.BalanceMonitor.get_all_balances(address) do
          {:ok, balances} ->
            formatted =
              Enum.map(balances, fn {chain_id, balance_wei} ->
                %{
                  chain_id: chain_id,
                  chain_name: chain_name(chain_id),
                  balance_wei: balance_wei,
                  balance_eth: wei_to_eth(balance_wei)
                }
              end)

            {:ok, %{address: address, balances: formatted}}

          {:error, :not_found} ->
            {:ok, %{address: address, balances: [], message: "Address not monitored. Call watch/2 first."}}
        end

      chain_id ->
        case Lux.Web3.BalanceMonitor.get_balance(address, chain_id) do
          {:ok, balance_wei} ->
            {:ok, %{
              address: address,
              chain_id: chain_id,
              chain_name: chain_name(chain_id),
              balance_wei: balance_wei,
              balance_eth: wei_to_eth(balance_wei)
            }}

          {:error, :not_found} ->
            {:ok, %{address: address, chain_id: chain_id, balance_wei: 0, message: "Balance not yet available"}}
        end
    end
  end

  defp wei_to_eth(wei) do
    Float.round(wei / 1.0e18, 8)
  end

  defp chain_name(1), do: "Ethereum Mainnet"
  defp chain_name(137), do: "Polygon"
  defp chain_name(42161), do: "Arbitrum One"
  defp chain_name(10), do: "Optimism"
  defp chain_name(8453), do: "Base"
  defp chain_name(id), do: "Chain #{id}"
end
