defmodule Lux.Rust do
  @moduledoc """
  Rust component definition support for Lux.

  This module mirrors the Python and Node.js language-support shape by providing a
  Rust sigil, component metadata builders, Cargo manifest generation, lifecycle
  plans, async runtime plans, and trait templates for native Prisms and Beams.
  It does not compile or load NIFs by itself; a Rust runtime adapter can execute
  the generated definitions.
  """

  @type component_kind :: :prism | :beam | :lens

  @module_path Application.app_dir(:lux, "priv/rust")

  @doc "Returns the Lux Rust support directory."
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @doc "Builds a Rust component definition from explicit metadata."
  @spec component_definition(map()) :: {:ok, map()} | {:error, term()}
  def component_definition(attrs) when is_map(attrs) do
    kind = attrs |> value(:kind, :prism) |> normalize_kind()

    with :ok <- ensure_known(kind, [:prism, :beam, :lens], :unknown_component_kind),
         {:ok, name} <- required(attrs, :name),
         {:ok, module} <- required(attrs, :module),
         {:ok, handler} <- required(attrs, :handler) do
      {:ok,
       %{
         language: :rust,
         kind: kind,
         name: to_string(name),
         module: to_string(module),
         handler: to_string(handler),
         async: value(attrs, :async, false),
         input_schema: value(attrs, :input_schema, %{}),
         output_schema: value(attrs, :output_schema, %{}),
         lifecycle: lifecycle_plan(attrs),
         runtime: runtime_plan(attrs),
         traits: traits_for(kind),
         code: value(attrs, :code)
       }}
    end
  end

  @doc "Builds a Prism-specific Rust component definition."
  def prism_definition(attrs), do: attrs |> Map.put(:kind, :prism) |> component_definition()

  @doc "Builds a Beam-specific Rust component definition."
  def beam_definition(attrs), do: attrs |> Map.put(:kind, :beam) |> component_definition()

  @doc "Builds a component definition from Rust code and options."
  def component_from_code(code, opts \\ []) when is_binary(code) do
    opts
    |> Map.new()
    |> Map.put_new(:name, "InlineRustComponent")
    |> Map.put_new(:module, "inline")
    |> Map.put_new(:handler, "handle")
    |> Map.put(:code, code)
    |> component_definition()
  end

  @doc "Generates a Cargo.toml manifest for a Lux Rust component crate."
  def cargo_manifest(attrs \\ %{}) do
    package = value(attrs, :package, "lux-rust-components")
    version = value(attrs, :version, "0.1.0")
    edition = value(attrs, :edition, "2021")
    crate_type = value(attrs, :crate_type, ["cdylib", "rlib"])

    dependencies =
      attrs
      |> value(:dependencies, default_dependencies())
      |> normalize_dependencies()

    """
    [package]
    name = "#{package}"
    version = "#{version}"
    edition = "#{edition}"

    [lib]
    crate-type = #{inspect(crate_type)}

    [dependencies]
    #{render_dependencies(dependencies)}
    """
  end

  @doc "Builds a dependency and cache plan for Rust components."
  def dependency_plan(attrs \\ %{}) do
    dependencies =
      attrs
      |> value(:dependencies, default_dependencies())
      |> normalize_dependencies()

    %{
      manifest_path: Path.join(module_path(), "Cargo.toml"),
      lockfile_path: Path.join(module_path(), "Cargo.lock"),
      cache_key: cache_key(dependencies),
      dependencies: dependencies,
      commands: [
        "cargo fetch --manifest-path #{Path.join(module_path(), "Cargo.toml")}",
        "cargo build --release --manifest-path #{Path.join(module_path(), "Cargo.toml")}"
      ]
    }
  end

  @doc "Builds a lifecycle plan for loading and calling a Rust component."
  def lifecycle_plan(attrs \\ %{}) do
    %{
      states: [:defined, :compiled, :loaded, :started, :called, :stopped],
      load: %{
        module: value(attrs, :module),
        symbol: value(attrs, :handler, "handle"),
        validates_schema: true
      },
      start: %{
        init: value(attrs, :init, "init"),
        resources: value(attrs, :resources, [])
      },
      call: %{
        timeout_ms: value(attrs, :timeout_ms, 5_000),
        error_boundary: :result_tuple,
        input_encoding: :json,
        output_encoding: :json
      },
      stop: %{
        callback: value(attrs, :stop, "shutdown"),
        release_resources: true
      }
    }
  end

  @doc "Builds async/await runtime options for Rust components."
  def runtime_plan(attrs \\ %{}) do
    %{
      runtime: value(attrs, :runtime, :tokio),
      async: value(attrs, :async, false),
      max_concurrency: value(attrs, :max_concurrency, System.schedulers_online()),
      cancellation: :cooperative,
      backpressure: %{
        queue_limit: value(attrs, :queue_limit, 128),
        overflow: value(attrs, :overflow, :reject)
      },
      performance: performance_plan(attrs)
    }
  end

  @doc "Builds performance options for native Rust components."
  def performance_plan(attrs \\ %{}) do
    %{
      zero_copy_candidates: value(attrs, :zero_copy_candidates, []),
      batch_size: value(attrs, :batch_size, 1),
      dirty_scheduler: value(attrs, :dirty_scheduler, false),
      telemetry: %{
        duration: true,
        queue_time: true,
        memory_bytes: true
      }
    }
  end

  @doc "Returns a Rust trait implementation template for a component."
  def component_template(attrs) when is_map(attrs) do
    name = value(attrs, :struct, "ExamplePrism")
    kind = attrs |> value(:kind, :prism) |> normalize_kind()

    """
    use lux_rust_components::{ComponentKind, LuxComponent, LuxError};
    use serde_json::{json, Value};

    pub struct #{name};

    impl LuxComponent for #{name} {
        fn name(&self) -> &'static str {
            "#{value(attrs, :name, name)}"
        }

        fn kind(&self) -> ComponentKind {
            ComponentKind::#{kind |> Atom.to_string() |> String.capitalize()}
        }

        fn handle(&self, input: Value) -> Result<Value, LuxError> {
            Ok(json!({
                "status": "ok",
                "input": input
            }))
        }
    }
    """
  end

  @doc "Validates a Rust component definition."
  def validate_component(%{
        language: :rust,
        name: name,
        module: module,
        handler: handler,
        traits: traits
      }) do
    errors =
      []
      |> maybe_add(blank?(name), :missing_name)
      |> maybe_add(blank?(module), :missing_module)
      |> maybe_add(blank?(handler), :missing_handler)
      |> maybe_add(traits == [], :missing_traits)

    %{valid: errors == [], errors: Enum.reverse(errors)}
  end

  def validate_component(_definition), do: %{valid: false, errors: [:not_a_rust_component]}

  @doc "Macro for defining inline Rust component code with default metadata."
  defmacro rust(do: block) do
    code =
      case block do
        {:sigil_RS, _, [{:<<>>, _, [string]}, []]} -> string
        {:__block__, _, [{:sigil_RS, _, [{:<<>>, _, [string]}, []]}]} -> string
      end

    quote do
      Lux.Rust.component_from_code(unquote(code))
    end
  end

  @doc false
  defmacro sigil_RS({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end

  defp default_dependencies do
    %{
      "serde" => %{version: "1", features: ["derive"]},
      "serde_json" => "1",
      "thiserror" => "1",
      "tokio" => %{version: "1", features: ["rt", "macros"]}
    }
  end

  defp normalize_dependencies(dependencies) when is_map(dependencies), do: dependencies

  defp normalize_dependencies(dependencies) when is_list(dependencies) do
    Map.new(dependencies, fn
      {name, version} -> {to_string(name), version}
      name -> {to_string(name), "*"}
    end)
  end

  defp render_dependencies(dependencies) do
    dependencies
    |> Enum.sort_by(fn {name, _value} -> name end)
    |> Enum.map_join("\n", fn
      {name, version} when is_binary(version) ->
        "#{name} = #{inspect(version)}"

      {name, opts} when is_map(opts) ->
        version = Map.fetch!(opts, :version)
        features = Map.get(opts, :features, [])
        "#{name} = { version = #{inspect(version)}, features = #{inspect(features)} }"
    end)
  end

  defp traits_for(:prism), do: [:lux_component, :lux_prism]
  defp traits_for(:beam), do: [:lux_component, :lux_beam]
  defp traits_for(:lens), do: [:lux_component, :lux_lens]

  defp cache_key(dependencies) do
    dependencies
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp normalize_kind(:prism), do: :prism
  defp normalize_kind(:beam), do: :beam
  defp normalize_kind(:lens), do: :lens
  defp normalize_kind("prism"), do: :prism
  defp normalize_kind("beam"), do: :beam
  defp normalize_kind("lens"), do: :lens
  defp normalize_kind(value), do: value

  defp required(map, key) do
    case value(map, key) do
      nil -> {:error, {:missing_required, key}}
      found -> {:ok, found}
    end
  end

  defp ensure_known(value, known, error), do: if(value in known, do: :ok, else: {:error, error})

  defp blank?(value), do: value in [nil, ""]

  defp maybe_add(list, true, value), do: [value | list]
  defp maybe_add(list, false, _value), do: list

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp value(_map, _key, default), do: default
end