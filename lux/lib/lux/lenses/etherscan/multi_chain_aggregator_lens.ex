defmodule Lux.Lenses.Etherscan.MultiChainAggregatorLens do
  @moduledoc """
  Module for aggregating data from multiple Etherscan chains.
  """

  alias Lux.Lenses.Etherscan.Base

  @doc """
  Aggregates data from multiple Etherscan chains.
  """
  def aggregate_data(chains, params) do
    Enum.reduce(chains, {:ok, []}, fn chain, acc ->
      case Base.add_api_key(%{params: params}) do
        %{params: updated_params} ->
          response = fetch_data_from_chain(chain, updated_params)
          process_response(response)

        error ->
          error
      end
    end)
  end

  defp fetch_data_from_chain(chain, params) do
    # Placeholder for actual API call logic
    {:ok, %{"result" => "data_from_#{chain}"}}
  end

  defp process_response(response) do
    Base.process_response(response)
  end
end