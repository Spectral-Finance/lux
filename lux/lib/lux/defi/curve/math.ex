defmodule Lux.Defi.Curve.Math do
  @moduledoc """
  Core mathematical operations for Curve Finance StableSwap invariant:
  - Newton-Raphson invariant D calculation
  - Output amount calculation (get_dy) with fee deduction
  - Deposit / withdrawal LP token mint calculation
  - Slippage and price impact
  - veCRV gauge boost calculation (1.0x to 2.5x working balance)
  """

  @precision 1_000_000_000_000_000_000

  @doc """
  Calculates the StableSwap invariant D given coin balances and amplification coefficient A.
  Balances must be normalized to 18 decimals.
  """
  @spec get_d(list(non_neg_integer()), pos_integer()) :: non_neg_integer()
  def get_d(balances, amp) when is_list(balances) and is_integer(amp) do
    n = length(balances)
    sum = Enum.sum(balances)

    if sum == 0 do
      0
    else
      ann = amp * n
      # Initial guess
      d_init = sum
      solve_d(d_init, balances, ann, n, 255)
    end
  end

  defp solve_d(d, _balances, _ann, _n, 0), do: d

  defp solve_d(d, balances, ann, n, iter) do
    # Calculate D_P = D^(n+1) / (n^n * prod(x))
    d_p =
      Enum.reduce(balances, d, fn x, acc ->
        # Safe division to prevent division by zero
        safe_x = max(x, 1)
        div(acc * d, safe_x * n)
      end)

    d_prev = d
    # Numerator: (Ann * sum + n * D_P) * D
    sum = Enum.sum(balances)
    numerator = (ann * sum + n * d_p) * d
    # Denominator: (Ann - 1) * D + (n + 1) * D_P
    denominator = (ann - 1) * d + (n + 1) * d_p

    d_next = div(numerator, max(denominator, 1))

    if abs(d_next - d_prev) <= 1 do
      d_next
    else
      solve_d(d_next, balances, ann, n, iter - 1)
    end
  end

  @doc """
  Calculates swap output amount `dy` when swapping `dx` of coin `i` to coin `j`.
  `fee_rate`: e.g. 0.0004 for 0.04% pool fee.
  """
  @spec get_dy(non_neg_integer(), non_neg_integer(), non_neg_integer(), list(non_neg_integer()), pos_integer(), float()) ::
          non_neg_integer()
  def get_dy(i, j, dx, balances, amp, fee_rate \\ 0.0004)
      when is_integer(i) and is_integer(j) and is_integer(dx) and i != j do
    d = get_d(balances, amp)
    n = length(balances)
    ann = amp * n

    # Update balance of token i
    new_balances_i = List.update_at(balances, i, &(&1 + dx))

    # Solve for new balance of token j
    new_y = solve_y(j, new_balances_i, ann, n, d)
    old_y = Enum.at(balances, j)

    dy_raw = old_y - new_y
    fee = round(dy_raw * fee_rate)
    max(dy_raw - fee, 0)
  end

  defp solve_y(j, balances, ann, n, d) do
    # Exclude j from sum and product calculation
    sum_without_j =
      balances
      |> List.delete_at(j)
      |> Enum.sum()

    # D_P without j
    c =
      Enum.reduce(Enum.with_index(balances), d, fn {x, idx}, acc ->
        if idx == j do
          acc
        else
          safe_x = max(x, 1)
          div(acc * d, safe_x * n)
        end
      end)

    c_final = div(c * d, ann * n)
    b = sum_without_j + div(d, ann)

    solve_y_newton(d, b, c_final, 255)
  end

  defp solve_y_newton(y, _b, _c, 0), do: y

  defp solve_y_newton(y, b, c, iter) do
    y_prev = y
    numerator = y * y + c
    denominator = 2 * y + b - div(numerator, max(y, 1))
    y_next = div(numerator, max(2 * y + b, 1))

    if abs(y_next - y_prev) <= 1 do
      y_next
    else
      solve_y_newton(y_next, b, c, iter - 1)
    end
  end

  @doc """
  Calculates the amount of LP tokens minted when depositing `amounts` into a pool.
  """
  @spec calc_lp_mint(list(non_neg_integer()), list(non_neg_integer()), pos_integer(), non_neg_integer()) ::
          non_neg_integer()
  def calc_lp_mint(deposit_amounts, current_balances, amp, total_lp_supply) do
    d0 = get_d(current_balances, amp)

    new_balances =
      Enum.zip(current_balances, deposit_amounts)
      |> Enum.map(fn {bal, dep} -> bal + dep end)

    d1 = get_d(new_balances, amp)

    if total_lp_supply == 0 do
      d1
    else
      diff_d = d1 - d0
      div(total_lp_supply * diff_d, max(d0, 1))
    end
  end

  @doc """
  Calculates gauge boost factor based on user veCRV holdings:
  working_balance = min(l_i, 0.4 * l_i + 0.6 * L * (v_i / V))
  boost = working_balance / (0.4 * l_i)
  Boost ranges from 1.0x (unboosted) to 2.5x (max boosted).
  """
  @spec calculate_gauge_boost(number(), number(), number(), number()) :: float()
  def calculate_gauge_boost(user_lp, total_lp, user_vecrv, total_vecrv)
      when user_lp > 0 and total_lp > 0 do
    l_i = user_lp
    big_l = total_lp
    v_i = max(user_vecrv, 0.0)
    big_v = max(total_vecrv, 1.0)

    vecrv_ratio = v_i / big_v
    working_balance = min(l_i, 0.4 * l_i + 0.6 * big_l * vecrv_ratio)

    boost = working_balance / (0.4 * l_i)
    Float.round(min(max(boost, 1.0), 2.5), 3)
  end

  def calculate_gauge_boost(_, _, _, _), do: 1.0
end
