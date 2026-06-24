defmodule Lux.Lenses.PancakeSwap.Farms.AutoCompound do
  @moduledoc """
  Sets up auto-compounding for a PancakeSwap farm position.

  ## Examples

      iex> AutoCompound.focus(%{farm_address: "0x...", reinvest_bounty_bps: 500})
      {:ok, %{status: "configured"}}
  """

  use Lux.Lens,
    name: "PancakeSwap Auto-Compound",
    description: "Configures auto-compounding for a PancakeSwap farm",
    schema: %{
      type: :object,
      properties: %{
        farm_address: %{type: :string, description: "The farm contract address"},
        reinvest_bounty_bps: %{
          type: :integer,
          description: "Bounty in basis points for reinvestment (default 500 = 5%)",
          default: 500
        }
      },
      required: ["farm_address"]
    }

  def after_focus(data) do
    {:ok, Map.put(data, :status, "configured")}
  end
end
