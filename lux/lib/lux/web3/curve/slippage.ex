defmodule Lux.Web3.Curve.Slippage do
  @moduledoc """
  Slippage optimisation helpers for Curve stablecoin swaps and liquidity events.

  All amounts are plain integers (wei style). Tolerances are expressed in basis
  points where `10_000` bps == 100%. The helpers are pure and validate their
  inputs, returning typed `{:error, reason}` tuples instead of raising.
  """

  @bps 10_000

  @doc """
  Computes the minimum amount to receive for a quoted output given a tolerance.

  The tolerance is applied conservatively with integer floor division so the
  returned minimum can never exceed the quote.

  ## Examples

      iex> Lux.Web3.Curve.Slippage.min_received(1_000_000, 50)
      {:ok, 995000}

      iex> Lux.Web3.Curve.Slippage.min_received(1_000, 10_000)
      {:ok, 0}
  """
  @spec min_received(term(), term()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def min_received(quoted_dy, tolerance_bps)
      when is_integer(quoted_dy) and quoted_dy >= 0 and is_integer(tolerance_bps) and
             tolerance_bps >= 0 and tolerance_bps <= @bps do
    {:ok, div(quoted_dy * (@bps - tolerance_bps), @bps)}
  end

  def min_received(quoted_dy, tolerance_bps)
      when is_integer(quoted_dy) and quoted_dy >= 0 and is_integer(tolerance_bps) do
    {:error, :invalid_tolerance}
  end

  def min_received(_quoted_dy, _tolerance_bps), do: {:error, :invalid_quote}

  @doc """
  Returns true when `received` is at or above `min_received`.

  This is a strict half-open comparison; equality is accepted.
  """
  @spec acceptable?(term(), term()) :: boolean()
  def acceptable?(received, min_received)
      when is_integer(received) and is_integer(min_received) do
    received >= min_received
  end

  def acceptable?(_received, _min_received), do: false

  @doc """
  Computes the realised price impact in basis points between an expected and an
  actual output amount.

  Returns `{:ok, impact_bps}` where `0` means no impact, or a typed error when
  the amounts are malformed or the actual output exceeds the expected output.
  """
  @spec price_impact_bps(term(), term()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def price_impact_bps(expected, actual)
      when is_integer(expected) and expected > 0 and is_integer(actual) and actual >= 0 and
             actual <= expected do
    {:ok, div((expected - actual) * @bps, expected)}
  end

  def price_impact_bps(expected, actual)
      when is_integer(expected) and is_integer(actual) and actual > expected and expected > 0 do
    {:error, :amount_exceeds_expected}
  end

  def price_impact_bps(_expected, _actual), do: {:error, :invalid_amounts}
end
