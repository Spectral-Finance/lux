defmodule Lux.Prisms.Web3.Gas.OptimizeTransaction do
  @moduledoc """
  Prism for gas-optimized transaction management.

  Supports submitting, speeding up, cancelling, batching, and simulating transactions.
  """

  use Lux.Prism,
    name: "Gas Optimize Transaction",
    description: "Submit, speed up, cancel, or batch transactions with gas optimization",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["submit", "speed_up", "cancel", "batch", "simulate", "cost"]},
        tx: %{type: :object},
        tx_id: %{type: :string},
        transactions: %{type: :array},
        gas_multiplier: %{type: :number},
        gas_limit: %{type: :integer},
        gas_price_gwei: %{type: :number},
        eth_price_usd: %{type: :number}
      },
      required: ["action"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Web3.Gas.{TransactionManager, Estimator}

  @impl true
  def handler(params, _opts) do
    action = params[:action] || params["action"]
    pid = params[:pid] || TransactionManager

    case action do
      "submit" ->
        tx = params[:tx] || params["tx"]
        TransactionManager.submit(pid, tx)

      "speed_up" ->
        tx_id = params[:tx_id] || params["tx_id"]
        multiplier = params[:gas_multiplier] || params["gas_multiplier"] || 1.5
        TransactionManager.speed_up(pid, tx_id, multiplier)

      "cancel" ->
        tx_id = params[:tx_id] || params["tx_id"]
        TransactionManager.cancel(pid, tx_id)

      "batch" ->
        txs = params[:transactions] || params["transactions"] || []
        TransactionManager.batch(pid, txs)

      "simulate" ->
        tx = params[:tx] || params["tx"] || %{}
        opts = [rpc_url: params[:rpc_url] || params["rpc_url"]]
        opts = if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
        Estimator.estimate_gas(tx, opts)

      "cost" ->
        gas_limit = params[:gas_limit] || params["gas_limit"] || 21_000
        gas_price = params[:gas_price_gwei] || params["gas_price_gwei"] || 30.0
        eth_price = params[:eth_price_usd] || params["eth_price_usd"]
        {:ok, Estimator.calculate_cost(gas_limit, gas_price, eth_price)}

      _ ->
        {:error, "Unknown action: #{action}"}
    end
  end
end
