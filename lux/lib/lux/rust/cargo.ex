defmodule Lux.Rust.Cargo do
  @moduledoc """
  Cargo manifest and dependency helpers for Lux Rust projects.

  This module keeps package-management concerns in Elixir while still emitting
  standard Cargo project files and command plans. It is useful for generated
  Rust projects, fixture projects, and future NIF/port integration work.
  """

  @default_package %{
    name: "lux_rust",
    version: "0.1.0",
    edition: "2021"
  }

  @type dependency_spec ::
          String.t()
          | keyword()
          | %{
              optional(:version) => String.t(),
              optional(:path) => String.t(),
              optional(:git) => String.t(),
              optional(:branch) => String.t(),
              optional(:tag) => String.t(),
              optional(:rev) => String.t(),
              optional(:features) => [String.t()],
              optional(:optional) => boolean(),
              optional(:default_features) => boolean()
            }

  @type manifest :: %{
          package: map(),
          dependencies: %{String.t() => map()},
          dev_dependencies: %{String.t() => map()},
          features: %{String.t() => [String.t()]}
        }

  @doc """
  Creates a normalized manifest map.
  """
  @spec new_manifest(keyword() | map()) :: manifest()
  def new_manifest(opts \\ []) do
    opts = Map.new(opts)

    %{
      package:
        @default_package
        |> Map.merge(string_key_map(Map.get(opts, :package, Map.get(opts, "package", %{}))))
        |> stringify_values(),
      dependencies: normalize_dependency_map(Map.get(opts, :dependencies, %{})),
      dev_dependencies: normalize_dependency_map(Map.get(opts, :dev_dependencies, %{})),
      features: normalize_features(Map.get(opts, :features, %{}))
    }
  end

  @doc """
  Adds or replaces a dependency in a manifest.
  """
  @spec add_dependency(manifest(), String.t() | atom(), dependency_spec(), keyword()) ::
          manifest()
  def add_dependency(manifest, name, spec, opts \\ []) do
    section = Keyword.get(opts, :section, :dependencies)
    dependency = normalize_dependency(name, spec)
    dependencies = Map.put(Map.get(manifest, section, %{}), dependency.name, dependency)
    Map.put(manifest, section, dependencies)
  end

  @doc """
  Normalizes a dependency specification.
  """
  @spec normalize_dependency(String.t() | atom(), dependency_spec()) :: map()
  def normalize_dependency(name, version) when is_binary(version) do
    %{name: to_string(name), version: version}
  end

  def normalize_dependency(name, spec) when is_list(spec) or is_map(spec) do
    spec =
      spec
      |> Map.new()
      |> Enum.map(fn {key, value} -> {normalize_key(key), value} end)
      |> Map.new()
      |> Map.put(:name, to_string(name))

    spec
  end

  @doc """
  Renders a manifest map into Cargo.toml content.
  """
  @spec to_toml(manifest()) :: String.t()
  def to_toml(manifest) do
    package = Map.fetch!(manifest, :package)

    sections = [
      render_section("package", package),
      render_dependency_section("dependencies", Map.get(manifest, :dependencies, %{})),
      render_dependency_section("dev-dependencies", Map.get(manifest, :dev_dependencies, %{})),
      render_features(Map.get(manifest, :features, %{}))
    ]

    sections
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  @doc """
  Parses the Cargo.toml shape emitted by `to_toml/1`.
  """
  @spec parse_toml(String.t()) :: manifest()
  def parse_toml(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.reduce({nil, new_manifest(package: %{})}, &parse_line/2)
    |> elem(1)
  end

  @doc """
  Writes a Cargo project structure if missing and returns the manifest path.
  """
  @spec ensure_project(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def ensure_project(project_path, opts \\ []) do
    manifest = Keyword.get_lazy(opts, :manifest, fn -> new_manifest(opts) end)
    manifest_path = Path.join(project_path, "Cargo.toml")
    lib_path = Path.join([project_path, "src", "lib.rs"])

    with :ok <- File.mkdir_p(Path.dirname(lib_path)),
         :ok <- maybe_write(manifest_path, to_toml(manifest), Keyword.get(opts, :force, false)),
         :ok <- maybe_write(lib_path, default_lib_rs(), Keyword.get(opts, :force, false)) do
      {:ok, manifest_path}
    end
  end

  @doc """
  Builds a deterministic Cargo command plan.
  """
  @spec command_plan(String.t(), atom(), keyword()) :: map()
  def command_plan(project_path, action, opts \\ []) do
    cargo = Keyword.get(opts, :cargo, "cargo")
    profile = Keyword.get(opts, :profile)
    locked? = Keyword.get(opts, :locked, true)
    features = Keyword.get(opts, :features, [])

    args =
      [to_string(action)]
      |> maybe_add(locked?, "--locked")
      |> maybe_add(profile == :release, "--release")
      |> maybe_add(features != [], "--features")
      |> maybe_add(features != [], Enum.join(features, ","))

    %{cd: Path.expand(project_path), command: [cargo | args], env: Keyword.get(opts, :env, [])}
  end

  @doc """
  Creates a stable cache key from package and dependency coordinates.
  """
  @spec cache_key(manifest()) :: String.t()
  def cache_key(manifest) do
    payload =
      manifest
      |> Map.take([:package, :dependencies, :dev_dependencies, :features])
      |> :erlang.term_to_binary()

    :crypto.hash(:sha256, payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Returns a conventional cache directory for Cargo artifacts.
  """
  @spec cache_dir(String.t(), manifest()) :: String.t()
  def cache_dir(base_path, manifest) do
    Path.join([base_path, ".cargo-cache", cache_key(manifest)])
  end

  defp parse_line(line, {section, manifest}) do
    line = line |> String.trim() |> strip_comment()

    cond do
      line == "" ->
        {section, manifest}

      String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
        {line |> String.trim_leading("[") |> String.trim_trailing("]"), manifest}

      String.contains?(line, "=") ->
        [key, value] = String.split(line, "=", parts: 2)
        apply_parsed_value(section, String.trim(key), parse_value(String.trim(value)), manifest)

      true ->
        {section, manifest}
    end
  end

  defp apply_parsed_value("package", key, value, manifest) do
    package = manifest.package |> Map.put(key, value)
    {"package", %{manifest | package: package}}
  end

  defp apply_parsed_value("dependencies", key, value, manifest) do
    dep = parsed_dependency(key, value)
    {"dependencies", %{manifest | dependencies: Map.put(manifest.dependencies, key, dep)}}
  end

  defp apply_parsed_value("dev-dependencies", key, value, manifest) do
    dep = parsed_dependency(key, value)

    {"dev-dependencies",
     %{manifest | dev_dependencies: Map.put(manifest.dev_dependencies, key, dep)}}
  end

  defp apply_parsed_value("features", key, value, manifest) when is_list(value) do
    {"features", %{manifest | features: Map.put(manifest.features, key, value)}}
  end

  defp apply_parsed_value(section, _key, _value, manifest), do: {section, manifest}

  defp parsed_dependency(name, version) when is_binary(version),
    do: %{name: name, version: version}

  defp parsed_dependency(name, attrs) when is_map(attrs), do: Map.put(attrs, :name, name)

  defp render_section(name, values) when map_size(values) == 0, do: "[#{name}]"

  defp render_section(name, values) do
    body =
      values
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map_join("\n", fn {key, value} -> "#{key} = #{render_value(value)}" end)

    "[#{name}]\n#{body}"
  end

  defp render_dependency_section(_name, dependencies) when map_size(dependencies) == 0, do: ""

  defp render_dependency_section(name, dependencies) do
    body =
      dependencies
      |> Enum.sort_by(fn {dep_name, _dep} -> dep_name end)
      |> Enum.map_join("\n", fn {dep_name, dep} ->
        "#{dep_name} = #{render_dependency(dep)}"
      end)

    "[#{name}]\n#{body}"
  end

  defp render_dependency(%{version: version} = dep) when map_size(dep) == 2 do
    render_value(version)
  end

  defp render_dependency(dep) do
    dep
    |> Map.drop([:name])
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map_join(", ", fn {key, value} -> "#{toml_key(key)} = #{render_value(value)}" end)
    |> then(&"{ #{&1} }")
  end

  defp render_features(features) when map_size(features) == 0, do: ""

  defp render_features(features) do
    body =
      features
      |> Enum.sort_by(fn {name, _values} -> name end)
      |> Enum.map_join("\n", fn {name, values} -> "#{name} = #{render_value(values)}" end)

    "[features]\n#{body}"
  end

  defp render_value(value) when is_binary(value), do: inspect(value)
  defp render_value(value) when is_boolean(value), do: to_string(value)

  defp render_value(value) when is_list(value),
    do: "[#{Enum.map_join(value, ", ", &render_value/1)}]"

  defp render_value(value), do: inspect(value)

  defp parse_value("\"" <> rest), do: rest |> String.trim_trailing("\"")

  defp parse_value("[" <> rest) do
    rest
    |> String.trim_trailing("]")
    |> split_csv()
    |> Enum.map(&parse_value/1)
  end

  defp parse_value("{" <> rest) do
    rest
    |> String.trim_trailing("}")
    |> split_csv()
    |> Enum.map(fn pair ->
      [key, value] = String.split(pair, "=", parts: 2)

      {key |> String.trim() |> String.replace("-", "_") |> String.to_atom(),
       parse_value(String.trim(value))}
    end)
    |> Map.new()
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value(value), do: value

  defp split_csv(""), do: []

  defp split_csv(value) do
    value
    |> String.graphemes()
    |> do_split_csv([], "", 0, false)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp do_split_csv([], acc, current, _depth, _quoted), do: Enum.reverse([current | acc])

  defp do_split_csv(["\"" | rest], acc, current, depth, quoted) do
    do_split_csv(rest, acc, current <> "\"", depth, not quoted)
  end

  defp do_split_csv([char | rest], acc, current, depth, false) when char in ["[", "{"] do
    do_split_csv(rest, acc, current <> char, depth + 1, false)
  end

  defp do_split_csv([char | rest], acc, current, depth, false) when char in ["]", "}"] do
    do_split_csv(rest, acc, current <> char, max(depth - 1, 0), false)
  end

  defp do_split_csv(["," | rest], acc, current, 0, false) do
    do_split_csv(rest, [current | acc], "", 0, false)
  end

  defp do_split_csv([char | rest], acc, current, depth, quoted) do
    do_split_csv(rest, acc, current <> char, depth, quoted)
  end

  defp normalize_dependency_map(dependencies) do
    dependencies
    |> Enum.map(fn {name, spec} ->
      dependency = normalize_dependency(name, spec)
      {dependency.name, dependency}
    end)
    |> Map.new()
  end

  defp normalize_features(features) do
    features
    |> Enum.map(fn {name, values} -> {to_string(name), Enum.map(values, &to_string/1)} end)
    |> Map.new()
  end

  defp string_key_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Map.new()
  end

  defp stringify_values(map) do
    map
    |> Enum.map(fn {key, value} -> {key, to_string(value)} end)
    |> Map.new()
  end

  defp normalize_key(:default_features), do: :default_features
  defp normalize_key("default-features"), do: :default_features
  defp normalize_key("default_features"), do: :default_features
  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key), do: key

  defp toml_key(:default_features), do: "default-features"
  defp toml_key(key), do: to_string(key)

  defp maybe_add(args, true, value), do: args ++ [value]
  defp maybe_add(args, false, _value), do: args

  defp maybe_write(path, content, true), do: File.write(path, content)

  defp maybe_write(path, content, false) do
    if File.exists?(path), do: :ok, else: File.write(path, content)
  end

  defp strip_comment(line) do
    line
    |> String.split("#", parts: 2)
    |> hd()
    |> String.trim()
  end

  defp default_lib_rs do
    """
    pub fn lux_rust_ready() -> bool {
        true
    }
    """
  end
end
