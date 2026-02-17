import Lux.Lenses.Curve.CurvePool
import Lux.Lenses.Curve.CurvePoolLens
  @moduledoc """
  Lens for interacting with curve pool data.
  """

  alias Lux.Lenses.Curve.CurvePool

  def select_optimal_pool(pools) do
    pools
    |> Enum.sort_by(&calculate_apr/1, :desc)
    |> List.first()
  end

  defp calculate_apr(pool) do
    # Placeholder for actual APR calculation logic
    # This is a simple example and should be replaced with the actual formula
    pool.virtual_price * pool.liquidity / 100
  end

  def create_pool(params) do
    CurvePool.create(params)
  end

  def update_pool(pool_id, params) do
    CurvePool.update(pool_id, params)
  end

  def delete_pool(pool_id) do
    CurvePool.delete(pool_id)
  end

  def get_liquidity(pool_id) do
    CurvePool.get_liquidity(pool_id)
  end

  def add_liquidity(pool_id, amount) do
    CurvePool.add_liquidity(pool_id, amount)
  end

  def remove_liquidity(pool_id, amount) do
    CurvePool.remove_liquidity(pool_id, amount)
  end

  def calculate_apy(pool_id) do
    CurvePool.calculate_apy(pool_id)
  end
end