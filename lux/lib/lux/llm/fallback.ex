defmodule Lux.LLM.Fallback do
  @moduledoc """
  Smart Fallback Engine for LLM provider failover in Lux.

  Executes a primary provider spec and transparently fails over to sequential fallback specs
  when encountering network errors, HTTP 429 (Rate Limit), or HTTP 503 (Service Unavailable).
  Attaches `fallback_history` to the resulting `Lux.Signal` metadata.
  """

  alias Lux.LLM.ProviderConfig
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Router
  alias Lux.Signal

  @type spec ::
          module()
          | {module() | atom(), map() | keyword()}
          | ProviderConfig.t()
          | (Lux.LLM.Provider.prompt(), Lux.LLM.Provider.tools() -> {:ok, Signal.t()} | {:error, term()})
          | (Lux.LLM.Provider.prompt(), Lux.LLM.Provider.tools(), map() | keyword() ->
               {:ok, Signal.t()} | {:error, term()})

  @doc """
  Executes an LLM call using a primary specification and transparently fails over through a list of fallback specifications.

  ## Options

  - `:primary` - The primary provider spec to try first. Default is `{Lux.LLM.Router, []}`.
  - `:fallbacks` - List of fallback provider specs to try sequentially if an error occurs.
  - `:fallback_on_all_errors` - Boolean flag. If true, fails over on any error, not just rate limits / network errors. Default: false.
  - `:registry_name` - Registry name passed when resolving atom provider IDs. Default: `Lux.LLM.ProviderRegistry`.
  """
  @spec call(Lux.LLM.Provider.prompt(), Lux.LLM.Provider.tools(), Lux.LLM.Provider.opts()) ::
          {:ok, Signal.t()} | {:error, term()}
  def call(prompt, tools \\ [], opts \\ []) do
    opts_map = to_map(opts)
    primary = Map.get(opts_map, :primary, {Router, opts_map})
    fallbacks = Map.get(opts_map, :fallbacks, [])

    specs = [primary | fallbacks]
    execute_specs(specs, prompt, tools, opts_map, [])
  end

  @doc """
  Convenience helper for executing a primary spec with an explicit fallback spec list.
  """
  @spec call_with_fallback(spec(), Lux.LLM.Provider.prompt(), Lux.LLM.Provider.tools(), Lux.LLM.Provider.opts(), [spec()]) ::
          {:ok, Signal.t()} | {:error, term()}
  def call_with_fallback(primary, prompt, tools \\ [], opts \\ [], fallbacks \\ []) do
    opts_map =
      opts
      |> to_map()
      |> Map.put(:primary, primary)
      |> Map.put(:fallbacks, fallbacks)

    call(prompt, tools, opts_map)
  end

  @status_codes [408, 429, 500, 502, 503, 504, 507, 529]
  @error_atoms [
    :rate_limit,
    :too_many_requests,
    :service_unavailable,
    :timeout,
    :connect_timeout,
    :econnrefused,
    :nxdomain,
    :closed,
    :etimedout,
    :econnreset
  ]

  @doc """
  Determines whether an error is eligible for failover (e.g., HTTP 429, 503, network errors).
  """
  @spec fallback_error?(term(), map() | keyword()) :: boolean()
  def fallback_error?(reason, opts \\ %{})

  def fallback_error?(reason, opts) when is_list(opts) do
    fallback_error?(reason, Enum.into(opts, %{}))
  end

  def fallback_error?(_reason, %{fallback_on_all_errors: true}), do: true

  def fallback_error?({status, _msg}, _opts) when status in @status_codes, do: true
  def fallback_error?(status, _opts) when status in @status_codes, do: true

  def fallback_error?(atom, _opts) when atom in @error_atoms, do: true

  def fallback_error?(%{status: status}, _opts) when status in @status_codes, do: true
  def fallback_error?(%{status_code: status}, _opts) when status in @status_codes, do: true
  def fallback_error?(%{reason: reason}, opts), do: fallback_error?(reason, opts)

  def fallback_error?(%struct{}, _opts)
      when struct in [Req.TransportError, Mint.TransportError],
      do: true

  def fallback_error?(reason, _opts) when is_binary(reason) do
    downcase = String.downcase(reason)

    Enum.any?(
      [
        "408", "429", "500", "502", "503", "504", "507", "529",
        "rate limit", "too many requests", "service unavailable",
        "overloaded", "connection refused", "connect timeout", "timeout",
        "econnrefused", "unavailable"
      ],
      &String.contains?(downcase, &1)
    )
  end

  def fallback_error?(tuple, _opts) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.any?(&fallback_error?(&1, %{}))
  end

  def fallback_error?(_reason, _opts), do: false

  # Internal execution loop

  defp execute_specs([], _prompt, _tools, _opts, history) do
    {:error, {:all_fallbacks_failed, Enum.reverse(history)}}
  end

  defp execute_specs([spec | remaining], prompt, tools, opts, history) do
    case safe_invoke_spec(spec, prompt, tools, opts) do
      {:ok, %Signal{} = signal} ->
        metadata = Map.get(signal, :metadata) || %{}
        updated_metadata = Map.put(metadata, :fallback_history, Enum.reverse(history))
        {:ok, %{signal | metadata: updated_metadata}}

      {:error, reason} ->
        attempt_record = %{
          spec: format_spec(spec),
          error: reason,
          timestamp: DateTime.utc_now()
        }

        new_history = [attempt_record | history]

        cond do
          remaining != [] and fallback_error?(reason, opts) ->
            execute_specs(remaining, prompt, tools, opts, new_history)

          remaining == [] ->
            {:error, {:all_fallbacks_failed, Enum.reverse(new_history)}}

          true ->
            # Non-retryable error encountered
            {:error, reason}
        end
    end
  end

  defp safe_invoke_spec(spec, prompt, tools, opts) do
    try do
      invoke_spec(spec, prompt, tools, opts)
    rescue
      e -> {:error, e}
    catch
      :exit, reason -> {:error, {:exit, reason}}
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp invoke_spec(fun, prompt, tools, _opts) when is_function(fun, 2) do
    fun.(prompt, tools)
  end

  defp invoke_spec(fun, prompt, tools, opts) when is_function(fun, 3) do
    fun.(prompt, tools, opts)
  end

  defp invoke_spec(Router, prompt, tools, global_opts) do
    Router.call(prompt, tools, global_opts)
  end

  defp invoke_spec({Router, spec_opts}, prompt, tools, global_opts) do
    merged = Map.merge(to_map(global_opts), to_map(spec_opts))
    Router.call(prompt, tools, merged)
  end

  defp invoke_spec({%ProviderConfig{} = config, spec_opts}, prompt, tools, global_opts) do
    merged = Map.merge(to_map(global_opts), to_map(spec_opts))
    call_opts = Router.build_call_opts(merged, config)
    config.module.call(prompt, tools, call_opts)
  end

  defp invoke_spec({module, spec_opts}, prompt, tools, global_opts) when is_atom(module) do
    merged = Map.merge(to_map(global_opts), to_map(spec_opts))

    cond do
      module == Router ->
        Router.call(prompt, tools, merged)

      Code.ensure_loaded?(module) and function_exported?(module, :call, 3) ->
        module.call(prompt, tools, Router.build_call_opts(merged))

      true ->
        resolve_and_call_provider(module, prompt, tools, merged)
    end
  end

  defp invoke_spec(%ProviderConfig{} = config, prompt, tools, global_opts) do
    call_opts = Router.build_call_opts(global_opts, config)
    config.module.call(prompt, tools, call_opts)
  end

  defp invoke_spec(module, prompt, tools, global_opts) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :call, 3) do
      module.call(prompt, tools, Router.build_call_opts(global_opts))
    else
      resolve_and_call_provider(module, prompt, tools, global_opts)
    end
  end

  defp resolve_and_call_provider(:router, prompt, tools, opts) do
    Router.call(prompt, tools, opts)
  end

  defp resolve_and_call_provider(provider_id, prompt, tools, opts) when is_atom(provider_id) do
    reg = Map.get(opts, :registry_name, ProviderRegistry)

    case lookup_provider(provider_id, reg) do
      {:ok, %ProviderConfig{} = config} ->
        call_opts = Router.build_call_opts(opts, config)
        config.module.call(prompt, tools, call_opts)

      {:error, _} ->
        call_standard_provider(provider_id, prompt, tools, opts)
    end
  end

  defp lookup_provider(provider_id, reg) do
    case GenServer.whereis(reg) do
      nil ->
        {:error, :registry_not_running}

      _pid ->
        try do
          ProviderRegistry.get_provider(provider_id, registry_name: reg)
        catch
          :exit, _ -> {:error, :registry_not_running}
        end
    end
  end

  defp call_standard_provider(provider_id, prompt, tools, opts) do
    module = standard_provider_module(provider_id)

    if Code.ensure_loaded?(module) and function_exported?(module, :call, 3) do
      module.call(prompt, tools, Router.build_call_opts(opts))
    else
      {:error, {:unknown_provider, provider_id}}
    end
  end

  defp standard_provider_module(:openai), do: Lux.LLM.OpenAI
  defp standard_provider_module(:gemini), do: Lux.LLM.Gemini
  defp standard_provider_module(:anthropic), do: Lux.LLM.Anthropic
  defp standard_provider_module(:open_router), do: Lux.LLM.OpenRouter
  defp standard_provider_module(:openrouter), do: Lux.LLM.OpenRouter
  defp standard_provider_module(:together_ai), do: Lux.LLM.TogetherAI
  defp standard_provider_module(:together), do: Lux.LLM.TogetherAI
  defp standard_provider_module(:mira), do: Lux.LLM.Mira
  defp standard_provider_module(mod), do: mod

  defp format_spec(%ProviderConfig{id: id}), do: "ProviderConfig(#{inspect(id)})"
  defp format_spec({mod, opts}) when is_atom(mod), do: "#{inspect(mod)}(#{inspect(opts)})"
  defp format_spec(mod) when is_atom(mod), do: inspect(mod)
  defp format_spec(fun) when is_function(fun), do: inspect(fun)
  defp format_spec(other), do: inspect(other)

  defp to_map(opts) when is_map(opts), do: opts
  defp to_map(opts) when is_list(opts), do: Enum.into(opts, %{})
  defp to_map(_), do: %{}
end
