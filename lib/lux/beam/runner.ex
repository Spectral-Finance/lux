defmodule Lux.Beam.Runner do
  @moduledoc """
  Executes beam definitions by running steps in sequence, parallel, or conditionally
  based on the beam's structure.
  """

  def run(beam, input, opts \\ []) do
    with :ok <- validate_input(beam, input) do
      initial_context = %{input: input, steps: %{}, step_index: 0}
      steps = Lux.Beam.steps(beam)

      case execute_steps(steps, initial_context) do
        {:ok, context} ->
          last_step = get_last_step(context)
          log = generate_execution_log(beam, context, opts[:agent], last_step)
          {:ok, last_step.result, log}

        {:error, error, context} ->
          log = generate_execution_log(beam, context, opts[:agent], nil)
          {:error, error, log}
      end
    end
  end

  defp validate_input(%Lux.Beam{input_schema: input_schema}, _input) do
    case input_schema do
      nil -> :ok
      _schema -> :ok
    end
  end

  # Handle composite steps
  defp execute_steps({:sequence, steps}, context) do
    steps
    |> List.flatten()
    |> Enum.reduce_while({:ok, context}, fn
      step, {:ok, acc_context} ->
        case execute_steps(step, acc_context) do
          {:ok, new_context} -> {:cont, {:ok, new_context}}
          error -> {:halt, error}
        end
    end)
  end

  defp execute_steps({:parallel, steps}, context) do
    base_index = context.step_index

    # Use Task.async_stream with ordered: true to maintain execution order
    results =
      steps
      |> List.flatten()
      |> Enum.with_index()
      |> Task.async_stream(
        fn {step, idx} ->
          # Each parallel step gets its own sequential index
          step_context = %{context | step_index: base_index + idx}
          execute_steps(step, step_context)
        end,
        # This ensures we process results in order
        ordered: true,
        on_timeout: :kill_task
      )
      |> Enum.reduce_while([], fn
        {:ok, {:ok, step_context}}, acc ->
          {:cont, [step_context | acc]}

        {:ok, {:error, error, step_context}}, _acc ->
          {:halt, {:error, error, step_context}}

        {:exit, _}, acc ->
          {:cont, acc}
      end)

    case results do
      {:error, error, step_context} ->
        {:error, error, step_context}

      contexts when is_list(contexts) ->
        # Merge results in reverse order since we accumulated them that way
        merged_context =
          contexts
          |> Enum.reverse()
          |> Enum.reduce(context, fn step_context, acc ->
            update_in(acc, [:steps], &Map.merge(&1, step_context.steps))
          end)

        # Update final step index
        final_index = base_index + length(contexts)
        {:ok, %{merged_context | step_index: final_index}}
    end
  end

  defp execute_steps({:branch, condition, branches}, context) do
    condition_result =
      case condition do
        {module, function} -> apply(module, function, [context])
        function when is_function(function, 1) -> function.(context)
      end

    case Enum.find(branches, fn {condition, _step} -> condition == condition_result end) do
      {_condition, steps} when is_list(steps) ->
        # Handle multiple steps in branch
        execute_steps({:sequence, steps}, context)

      {_condition, step} ->
        execute_steps(step, context)

      nil ->
        {:error, :no_matching_branch, context}
    end
  end

  defp execute_steps(%{id: _id, module: _module, params: _params, opts: _opts} = step, context) do
    execute_step(step, context)
  end

  defp execute_steps(step, context) when not is_nil(step) do
    execute_step(step, context)
  end

  defp execute_step(%{id: id, module: module, params: params, opts: opts}, context) do
    resolved_params = resolve_params(params, context)
    started_at = DateTime.utc_now()
    step_index = context.step_index

    try do
      case apply(module, :handler, [resolved_params, context]) do
        {:ok, result} ->
          step_result = %{
            input: resolved_params,
            result: result,
            status: :completed,
            started_at: started_at,
            completed_at: DateTime.utc_now(),
            error: nil,
            step_index: step_index
          }

          {:ok,
           context
           |> put_in([:steps, id], step_result)
           |> Map.put(:step_index, step_index + 1)}

        {:error, error} ->
          handle_step_error(
            id,
            module,
            resolved_params,
            opts,
            error,
            context,
            started_at,
            step_index
          )
      end
    rescue
      error ->
        handle_step_error(
          id,
          module,
          resolved_params,
          opts,
          error,
          context,
          started_at,
          step_index
        )
    end
  end

  defp handle_step_error(
         id,
         module,
         params,
         %{retries: retries} = opts,
         _error,
         context,
         _started_at,
         _step_index
       )
       when retries > 0 do
    Process.sleep(opts.retry_backoff)

    execute_step(
      %{
        id: id,
        module: module,
        params: params,
        opts: %{opts | retries: retries - 1}
      },
      context
    )
  end

  defp handle_step_error(
         id,
         _module,
         params,
         %{fallback: fallback} = _opts,
         error,
         context,
         started_at,
         step_index
       )
       when not is_nil(fallback) do
    case apply_fallback(fallback, %{error: error, context: context}) do
      {:continue, result} ->
        step_result = %{
          input: params,
          result: result,
          status: :completed,
          started_at: started_at,
          completed_at: DateTime.utc_now(),
          error: nil,
          step_index: step_index
        }

        {:ok,
         context
         |> put_in([:steps, id], step_result)
         |> Map.put(:step_index, step_index + 1)}

      {:stop, result} ->
        step_result = %{
          input: params,
          result: nil,
          status: :failed,
          started_at: started_at,
          completed_at: DateTime.utc_now(),
          error: result,
          step_index: step_index
        }

        {:error, result,
         context
         |> put_in([:steps, id], step_result)
         |> Map.put(:step_index, step_index + 1)}
    end
  end

  defp handle_step_error(id, _module, params, _opts, error, context, started_at, step_index) do
    step_result = %{
      input: params,
      result: nil,
      status: :failed,
      started_at: started_at,
      completed_at: DateTime.utc_now(),
      error: error,
      step_index: step_index
    }

    {:error, error,
     context
     |> put_in([:steps, id], step_result)
     |> Map.put(:step_index, step_index + 1)}
  end

  defp apply_fallback(fallback, params) when is_function(fallback, 1) do
    fallback.(params)
  end

  defp apply_fallback(fallback, params) when is_atom(fallback) do
    apply(fallback, :handle_error, [params])
  end

  defp resolve_params(params, context) when is_map(params) do
    # If params is a map, construct a new map with resolved values
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, key, resolve_value(value, context))
    end)
  end

  defp resolve_params(value, context) do
    # If params is not a map, resolve it directly
    resolve_value(value, context)
  end

  # Handle access paths (must start with :input or :steps)
  defp resolve_value([root | _] = path, context) when root in [:input, :steps] do
    get_in(context, path)
  end

  # Handle all other values as literals
  defp resolve_value(value, _context), do: value

  defp get_last_step(context) do
    context.steps
    |> Enum.sort_by(fn {_key, step} -> step.step_index end, :desc)
    |> List.first()
    |> elem(1)
  end

  defp generate_execution_log(beam, context, agent, last_step) do
    if beam.generate_execution_log do
      # Get ordered steps to find first and last timestamps
      ordered_steps =
        context.steps
        |> Enum.sort_by(fn {_id, step} -> step.step_index end)
        |> Enum.map(fn {id, step_data} ->
          %{
            id: id,
            status: step_data.status,
            started_at: step_data.started_at,
            completed_at: step_data.completed_at,
            input: step_data.input,
            output: step_data.result,
            error: step_data.error,
            step_index: step_data.step_index
          }
        end)

      first_step = List.first(ordered_steps)
      last_executed_step = List.last(ordered_steps)

      %{
        beam_id: beam.id,
        started_by: agent || "system",
        started_at: (first_step && first_step.started_at) || DateTime.utc_now(),
        completed_at:
          (last_executed_step && last_executed_step.completed_at) || DateTime.utc_now(),
        status: if(last_step && last_step.status == :completed, do: :completed, else: :failed),
        input: context.input,
        output: last_step && last_step.result,
        steps: ordered_steps
      }
    end
  end
end
