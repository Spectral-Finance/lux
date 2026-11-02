defmodule Lux.Prisms.Defi.Curve.DepositAndStakePrism do
  @moduledoc """
  Deposits stablecoins into a Curve pool and automatically stakes minted LP tokens into the corresponding gauge.
  """

  use Lux.Prism,
    name: "Deposit and Stake into Curve",
    description: "Mints Curve LP tokens from coin deposits and stakes them into the LiquidityGauge",
    input_schema: %{
      type: :object,
      properties: %{
        owner: %{type: :string, description: "Wallet address of depositor"},
        pool_id: %{type: :string, default: "3pool"},
        amounts: %{type: :array, items: %{type: :integer}, description: "Deposit amounts for each coin"},
        current_balances: %{type: :array, items: %{type: :integer}, description: "Current pool balances"},
        amp: %{type: :integer, default: 2000},
        total_lp_supply: %{type: :integer, default: 1000000000},
        stake_in_gauge: %{type: :boolean, default: true}
      },
      required: ["owner", "amounts", "current_balances"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        position_id: %{type: :string},
        minted_lp: %{type: :integer},
        staked_in_gauge: %{type: :integer},
        wallet_lp: %{type: :integer}
      },
      required: ["position_id", "minted_lp", "staked_in_gauge"]
    }

  alias Lux.Defi.Curve.PositionManager
  alias Lux.Defi.Curve.GaugeManager

  def handler(input, _ctx) do
    owner = Map.get(input, :owner) || Map.get(input, "owner", "0x0000000000000000000000000000000000000000")
    pool_id = Map.get(input, :pool_id) || Map.get(input, "pool_id", "3pool")
    amounts = Map.get(input, :amounts) || Map.get(input, "amounts", [])
    balances = Map.get(input, :current_balances) || Map.get(input, "current_balances", [])
    amp = Map.get(input, :amp) || Map.get(input, "amp", 2000)
    supply = Map.get(input, :total_lp_supply) || Map.get(input, "total_lp_supply", 1_000_000_000)
    auto_stake = Map.get(input, :stake_in_gauge) || Map.get(input, "stake_in_gauge", true)

    pos = PositionManager.create_position(owner, pool_id)

    case PositionManager.deposit(pos, amounts, balances, amp, supply) do
      {:ok, deposited_pos, minted_lp} ->
        final_pos =
          if auto_stake do
            case GaugeManager.stake(deposited_pos, minted_lp) do
              {:ok, staked_pos} -> staked_pos
              _ -> deposited_pos
            end
          else
            deposited_pos
          end

        {:ok,
         %{
           position_id: final_pos.id,
           minted_lp: minted_lp,
           staked_in_gauge: final_pos.staked_in_gauge,
           wallet_lp: final_pos.lp_balance
         }}

      {:error, reason} ->
        {:error, "Deposit failed: #{inspect(reason)}"}
    end
  end
end
