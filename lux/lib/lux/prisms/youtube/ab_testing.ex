defmodule Lux.Prisms.YouTube.ABTesting do
  @moduledoc """
  A/B testing framework for YouTube content (thumbnails, titles, descriptions).
  """

  use GenServer

  defstruct [:experiments]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def create_experiment(pid \\ __MODULE__, params) do
    GenServer.call(pid, {:create, params})
  end

  def record_impression(pid \\ __MODULE__, experiment_id, variant) do
    GenServer.call(pid, {:impression, experiment_id, variant})
  end

  def record_click(pid \\ __MODULE__, experiment_id, variant) do
    GenServer.call(pid, {:click, experiment_id, variant})
  end

  def get_results(pid \\ __MODULE__, experiment_id) do
    GenServer.call(pid, {:results, experiment_id})
  end

  def list_experiments(pid \\ __MODULE__) do
    GenServer.call(pid, :list)
  end

  def conclude(pid \\ __MODULE__, experiment_id) do
    GenServer.call(pid, {:conclude, experiment_id})
  end

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{experiments: %{}}}

  @impl true
  def handle_call({:create, params}, _from, state) do
    id = params[:id] || gen_id()
    variants = Enum.map(params[:variants] || ["A", "B"], fn v ->
      {v, %{impressions: 0, clicks: 0}}
    end) |> Map.new()

    experiment = %{
      id: id,
      name: params[:name] || "Experiment #{id}",
      type: params[:type] || :thumbnail,
      video_id: params[:video_id],
      variants: variants,
      status: :running,
      created_at: DateTime.utc_now(),
      concluded_at: nil,
      winner: nil
    }
    {:reply, {:ok, experiment}, %{state | experiments: Map.put(state.experiments, id, experiment)}}
  end

  @impl true
  def handle_call({:impression, exp_id, variant}, _from, state) do
    update_variant(state, exp_id, variant, :impressions)
  end

  @impl true
  def handle_call({:click, exp_id, variant}, _from, state) do
    update_variant(state, exp_id, variant, :clicks)
  end

  @impl true
  def handle_call({:results, exp_id}, _from, state) do
    case Map.get(state.experiments, exp_id) do
      nil -> {:reply, {:error, :not_found}, state}
      exp ->
        results = exp.variants
        |> Enum.map(fn {name, data} ->
          ctr = if data.impressions > 0, do: Float.round(data.clicks / data.impressions * 100, 2), else: 0.0
          {name, Map.put(data, :ctr, ctr)}
        end)
        |> Map.new()

        {:reply, {:ok, %{experiment: exp.name, status: exp.status, variants: results, winner: exp.winner}}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, {:ok, Map.values(state.experiments)}, state}
  end

  @impl true
  def handle_call({:conclude, exp_id}, _from, state) do
    case Map.get(state.experiments, exp_id) do
      nil -> {:reply, {:error, :not_found}, state}
      exp ->
        winner = exp.variants
        |> Enum.max_by(fn {_, data} ->
          if data.impressions > 0, do: data.clicks / data.impressions, else: 0
        end)
        |> elem(0)

        updated = %{exp | status: :concluded, concluded_at: DateTime.utc_now(), winner: winner}
        {:reply, {:ok, %{winner: winner, experiment: updated}},
         %{state | experiments: Map.put(state.experiments, exp_id, updated)}}
    end
  end

  defp update_variant(state, exp_id, variant, field) do
    case Map.get(state.experiments, exp_id) do
      nil -> {:reply, {:error, :not_found}, state}
      exp ->
        case Map.get(exp.variants, variant) do
          nil -> {:reply, {:error, :unknown_variant}, state}
          data ->
            updated_data = Map.update!(data, field, &(&1 + 1))
            updated_exp = %{exp | variants: Map.put(exp.variants, variant, updated_data)}
            {:reply, :ok, %{state | experiments: Map.put(state.experiments, exp_id, updated_exp)}}
        end
    end
  end

  defp gen_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
