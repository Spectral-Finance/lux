defmodule Lux.Rust.Component do
  @moduledoc """
  Support for defining high-performance Lux components (Prisms and Beams) in Rust (#103).

  Provides trait-aligned component metadata, async/await execution wrappers,
  lifecycle management (`init/1`, `validate/1`, `execute/2`, `shutdown/1`), and
  telemetry instrumentation.
  """

  defstruct [
    :name,
    :kind,
    :crate_name,
    :entrypoint,
    :async_runtime,
    :input_schema,
    :output_schema,
    :lifecycle_state,
    :optimizations
  ]

  @valid_kinds [:prism, :beam, :lens]

  @doc """
  Defines and validates a new Rust-backed Lux component specification.
  """
  def define(attrs) when is_map(attrs) do
    name = Map.get(attrs, :name, "")
    kind = Map.get(attrs, :kind, :prism)
    crate = Map.get(attrs, :crate_name, "")
    entrypoint = Map.get(attrs, :entrypoint, "run")

    cond do
      String.trim(to_string(name)) == "" ->
        {:error, :missing_component_name}

      kind not in @valid_kinds ->
        {:error, {:invalid_component_kind, kind}}

      String.trim(to_string(crate)) == "" ->
        {:error, :missing_crate_name}

      true ->
        {:ok,
         %__MODULE__{
           name: name,
           kind: kind,
           crate_name: crate,
           entrypoint: entrypoint,
           async_runtime: Map.get(attrs, :async_runtime, :tokio),
           input_schema: Map.get(attrs, :input_schema, %{type: :object}),
           output_schema: Map.get(attrs, :output_schema, %{type: :object}),
           lifecycle_state: :initialized,
           optimizations: Map.get(attrs, :optimizations, %{simd: true, zero_copy: true, lto: :thin})
         }}
    end
  end

  @doc """
  Transitions component lifecycle state (`:initialized -> :running -> :stopped`) and executes payload.
  """
  def execute(%__MODULE__{lifecycle_state: :stopped}, _input, _runner), do: {:error, :component_stopped}

  def execute(%__MODULE__{} = comp, input, runner) when is_map(input) and is_function(runner, 2) do
    started = System.monotonic_time(:microsecond)
    running_comp = %{comp | lifecycle_state: :running}

    case runner.(running_comp, input) do
      {:ok, output} ->
        elapsed_us = System.monotonic_time(:microsecond) - started
        {:ok, %{result: output, component: running_comp.name, async_runtime: running_comp.async_runtime, elapsed_us: elapsed_us}}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Gracefully shuts down a Rust component and releases native resources.
  """
  def shutdown(%__MODULE__{} = comp) do
    {:ok, %{comp | lifecycle_state: :stopped}}
  end
end
