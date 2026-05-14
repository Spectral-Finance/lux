defmodule Lux.Prisms.Web3.GasTransactionManager do
  @moduledoc """
  Prism for deterministic gas optimization and transaction management plans.
  """

  use Lux.Prism,
    name: "Web3 Gas Transaction Manager",
    description:
      "Builds gas prediction, batching, replacement, MEV protection, simulation, and cost analysis plans",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "predict_gas",
            "batch_transactions",
            "replacement_transaction",
            "mev_protection_plan",
            "gas_token_strategy",
            "simulate_transaction",
            "cost_report",
            "management_plan"
          ]
        },
        params: %{type: :object}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status", "result"]
    }

  alias Lux.Web3.GasTransactionManager, as: Manager

  def handler(%{action: "predict_gas"} = input, _ctx),
    do: input |> params() |> Manager.predict_gas() |> normalize()

  def handler(%{action: "batch_transactions"} = input, _ctx) do
    input
    |> params()
    |> then(&Manager.batch_transactions(Map.get(&1, :transactions, []), Map.get(&1, :opts, %{})))
    |> normalize()
  end

  def handler(%{action: "replacement_transaction"} = input, _ctx) do
    input |> params() |> Manager.replacement_transaction() |> normalize()
  end

  def handler(%{action: "mev_protection_plan"} = input, _ctx) do
    input |> params() |> Manager.mev_protection_plan() |> normalize()
  end

  def handler(%{action: "gas_token_strategy"} = input, _ctx) do
    input |> params() |> Manager.gas_token_strategy() |> normalize()
  end

  def handler(%{action: "simulate_transaction"} = input, _ctx) do
    input |> params() |> Manager.simulate_transaction() |> normalize()
  end

  def handler(%{action: "cost_report"} = input, _ctx),
    do: input |> params() |> Manager.cost_report() |> normalize()

  def handler(%{action: "management_plan"} = input, _ctx),
    do: input |> params() |> Manager.management_plan() |> normalize()

  def handler(_input, _ctx), do: {:error, "Unsupported Web3 gas transaction operation"}

  defp params(input), do: Map.get(input, :params, %{})
  defp normalize({:ok, result}), do: {:ok, %{status: "success", result: result}}
  defp normalize({:error, reason}), do: {:error, reason}
end
