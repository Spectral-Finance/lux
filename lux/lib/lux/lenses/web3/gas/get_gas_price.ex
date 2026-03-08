defmodule Lux.Lenses.Web3.Gas.GetGasPrice do
  @moduledoc """
  Lens for fetching current gas prices with slow/standard/fast tiers.
  """

  alias Lux.Integrations.Web3.Gas.Estimator

  def focus(params, _opts \\ []) do
    opts = [rpc_url: params[:rpc_url] || params["rpc_url"]]
    opts = if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts

    Estimator.estimate(opts)
  end
end
