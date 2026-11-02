defmodule Lux.Defi.Curve.PoolManager do
  @moduledoc """
  Curve pool registry, virtual price calculation, and balance depeg monitoring.
  """

  alias Lux.Defi.Curve.Math

  @pools %{
    "3pool" => %{
      id: "3pool",
      name: "Curve 3pool (DAI/USDC/USDT)",
      address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      lp_token: "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490",
      gauge: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
      coins: [
        %{symbol: "DAI", address: "0x6B175474E89094C44Da98b954EedeAC495271d0F", decimals: 18},
        %{symbol: "USDC", address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", decimals: 6},
        %{symbol: "USDT", address: "0xdAC17F958D2ee523a2206206994597C13D831ec7", decimals: 6}
      ],
      amp: 2000,
      fee: 0.0004
    },
    "crvusd_usdc" => %{
      id: "crvusd_usdc",
      name: "crvUSD/USDC",
      address: "0x4eBd0D703D8839A610056DC56095C3C9E188d584",
      lp_token: "0x4eBd0D703D8839A610056DC56095C3C9E188d584",
      gauge: "0x959C8D50b716E5336d3542E7e2B6780c850257B8",
      coins: [
        %{symbol: "crvUSD", address: "0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E", decimals: 18},
        %{symbol: "USDC", address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", decimals: 6}
      ],
      amp: 1000,
      fee: 0.0002
    }
  }

  @doc """
  Lists all pre-configured Curve pools.
  """
  @spec list_pools() :: list(map())
  def list_pools, do: Map.values(@pools)

  @doc """
  Retrieves a pool by its ID or contract address.
  """
  @spec get_pool(String.t()) :: {:ok, map()} | {:error, :pool_not_found}
  def get_pool(id_or_addr) when is_binary(id_or_addr) do
    clean = String.downcase(id_or_addr)

    found =
      Enum.find(@pools, fn {id, pool} ->
        String.downcase(id) == clean or String.downcase(pool.address) == clean
      end)

    case found do
      {_, pool} -> {:ok, pool}
      nil -> {:error, :pool_not_found}
    end
  end

  @doc """
  Calculates the virtual price of a pool:
  virtual_price = D / total_lp_supply
  """
  @spec calculate_virtual_price(list(non_neg_integer()), pos_integer(), non_neg_integer()) :: float()
  def calculate_virtual_price(balances, amp, total_lp_supply) when total_lp_supply > 0 do
    d = Math.get_d(balances, amp)
    Float.round(d / total_lp_supply, 6)
  end

  def calculate_virtual_price(_, _, _), do: 1.0

  @doc """
  Evaluates pool balance shares and detects if any coin depegs or deviates past threshold.
  """
  @spec analyze_balances(list(number()), float()) :: %{
          shares: list(float()),
          imbalanced?: boolean(),
          underrepresented_index: non_neg_integer(),
          max_deviation_pct: float()
        }
  def analyze_balances(balances, threshold_pct \\ 0.05) when is_list(balances) do
    total = max(Enum.sum(balances), 1.0)
    n = length(balances)
    ideal_share = 1.0 / n

    shares = Enum.map(balances, fn b -> Float.round(b / total, 4) end)

    deviations =
      Enum.map(shares, fn s ->
        abs(s - ideal_share)
      end)

    max_dev = Enum.max(deviations)
    imbalanced = max_dev >= threshold_pct

    # Index of coin with lowest balance
    {_, min_idx} =
      Enum.with_index(shares)
      |> Enum.min_by(fn {s, _} -> s end)

    %{
      shares: shares,
      imbalanced?: imbalanced,
      underrepresented_index: min_idx,
      max_deviation_pct: Float.round(max_dev * 100.0, 2)
    }
  end
end
