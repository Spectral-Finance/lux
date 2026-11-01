defmodule Lux.Prisms.GasOptimizerPrism do
  @moduledoc """
  A Prism for autonomous agents to execute gas optimization, transaction batching,
  MEV protection, and transaction replacement.

  ## Examples

      iex> Lux.Prisms.GasOptimizerPrism.run(%{
      ...>   action: "predict",
      ...>   payload: %{tier: "fast"}
      ...> })
      {:ok, %{action: "predict", result: %{base_fee_gwei: 25.0, ...}}}
  """

  use Lux.Prism,
    name: "Gas Optimizer",
    description: "Optimizes Ethereum gas fees, bundles batch calls, simulates execution, and protects against MEV",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["predict", "batch", "speed_up", "cancel", "mev_check", "simulate", "optimize"],
          description: "Optimization operation to execute",
          default: "predict"
        },
        payload: %{
          type: :object,
          description: "Arguments and parameters for the selected action"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action performed"
        },
        result: %{
          type: :object,
          description: "Resulting data payload"
        }
      },
      required: ["action", "result"]
    }

  alias Lux.Web3.Gas

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "predict")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "GasOptimizerPrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("predict", payload) do
    tier_str = Map.get(payload, :tier) || Map.get(payload, "tier", "standard")
    tier = String.to_existing_atom(tier_str)
    {:ok, Gas.predict_fees(tier, payload)}
  rescue
    _ -> {:ok, Gas.predict_fees(:standard, payload)}
  end

  defp execute_action("batch", payload) do
    calls = Map.get(payload, :calls) || Map.get(payload, "calls", [])
    Gas.create_batch(calls)
  end

  defp execute_action("speed_up", payload) do
    tx = Map.get(payload, :tx) || Map.get(payload, "tx", payload)
    multiplier = Map.get(payload, :bump_multiplier, 1.15)
    Gas.speed_up(tx, multiplier)
  end

  defp execute_action("cancel", payload) do
    tx = Map.get(payload, :tx) || Map.get(payload, "tx", payload)
    multiplier = Map.get(payload, :bump_multiplier, 1.25)
    Gas.cancel(tx, multiplier)
  end

  defp execute_action("mev_check", payload) do
    {:ok, Gas.protect_mev(payload)}
  end

  defp execute_action("simulate", payload) do
    {:ok, Gas.simulate(payload)}
  end

  defp execute_action("optimize", payload) do
    Gas.optimize(payload)
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end
end
