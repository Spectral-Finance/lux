defmodule Lux.Lenses.Hyperliquid.Trading.AssessRisk do
  @moduledoc """
  Assesses risk for Hyperliquid positions.

  Delegates to `Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism`.

  ## Examples

      iex> AssessRisk.focus(%{})
      {:ok, %{risk_assessment: %{...}}}
  """

  use Lux.Lens,
    name: "Hyperliquid Assess Risk",
    description: "Assesses risk for Hyperliquid positions",
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def focus(_params) do
    Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism.run(%{})
  end
end
