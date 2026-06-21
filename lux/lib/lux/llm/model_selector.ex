defmodule Lux.LLM.ModelSelector do
  @moduledoc """
  Intelligent model selection based on cost and capability constraints.

  ## Usage

      models = [
        %{id: "gpt-4", cost_per_input_token: 0.03, capabilities: [:chat, :function_calling]},
        %{id: "gpt-3.5-turbo", cost_per_input_token: 0.001, capabilities: [:chat]}
      ]

      {:ok, model} = Lux.LLM.ModelSelector.select(models, required_capabilities: [:chat])
      # => cheapest capable model

  """

  @type capability :: atom()
  @type model_config :: %{
          id: String.t(),
          cost_per_input_token: float(),
          capabilities: [capability()]
        }
  @type select_opts :: [
          required_capabilities: [capability()],
          max_cost_per_token: float() | nil
        ]

  @doc """
  Selects the cheapest model that satisfies all required capabilities.

  ## Examples

      iex> models = [%{id: "a", cost_per_input_token: 0.01, capabilities: [:chat]},
      ...>           %{id: "b", cost_per_input_token: 0.001, capabilities: [:chat]}]
      iex> Lux.LLM.ModelSelector.select(models, required_capabilities: [:chat])
      {:ok, %{id: "b", cost_per_input_token: 0.001, capabilities: [:chat]}}

  """
  @spec select([model_config()], select_opts()) ::
          {:ok, model_config()} | {:error, :no_suitable_model}
  def select(models, opts \\ []) do
    required = Keyword.get(opts, :required_capabilities, [])
    max_cost = Keyword.get(opts, :max_cost_per_token, nil)

    models
    |> Enum.filter(&has_capabilities?(&1, required))
    |> Enum.filter(&within_cost?(&1, max_cost))
    |> Enum.sort_by(& &1.cost_per_input_token)
    |> case do
      [] -> {:error, :no_suitable_model}
      [best | _] -> {:ok, best}
    end
  end

  @doc """
  Returns all models satisfying the given requirements, sorted by cost ascending.
  """
  @spec select_all([model_config()], select_opts()) :: [model_config()]
  def select_all(models, opts \\ []) do
    required = Keyword.get(opts, :required_capabilities, [])
    max_cost = Keyword.get(opts, :max_cost_per_token, nil)

    models
    |> Enum.filter(&has_capabilities?(&1, required))
    |> Enum.filter(&within_cost?(&1, max_cost))
    |> Enum.sort_by(& &1.cost_per_input_token)
  end

  defp has_capabilities?(model, required) do
    caps = Map.get(model, :capabilities, [])
    Enum.all?(required, &(&1 in caps))
  end

  defp within_cost?(_model, nil), do: true

  defp within_cost?(model, max) do
    Map.get(model, :cost_per_input_token, 0.0) <= max
  end
end
