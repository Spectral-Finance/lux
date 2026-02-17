defmodule Lux.Prisms.Curve.GaugeStakePrism do
  @moduledoc """
  Module for handling gauge staking and CRV rewards claiming.
  """

  alias Lux.{Blockchain, Prisms}

  def stake_gauge(user_address, pool_id) do
    with {:ok, _tx} <- Blockchain.send_transaction(%{
      from: user_address,
      to: "0xPoolAddress",
      data: "0xStakeGaugeFunction#{pool_id}"
    }) do
      {:ok, "Staked successfully"}
    else
      error -> {:error, error}
    end
  end

  def claim_rewards(user_address) do
    with {:ok, _tx} <- Blockchain.send_transaction(%{
      from: user_address,
      to: "0xGaugeAddress",
      data: "0xClaimRewardsFunction"
    }) do
      {:ok, "Rewards claimed successfully"}
    else
      error -> {:error, error}
    end
  end
end