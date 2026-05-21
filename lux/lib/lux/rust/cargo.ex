defmodule Lux.Rust.Cargo do
  @moduledoc """
  Cargo package-management integration for Rust projects in Lux.

  The module covers the Cargo workflows Lux needs when generating or managing
  Rust code from Elixir:

    * Cargo.toml manifest generation plus safe dependency patching
    * dependency normalization and lockfile inspection from Cargo.lock or an
      injected version index
    * build/fetch/test command planning and execution through Cargo
    * cache-key generation for manifests, lockfiles, and Cargo directories

  The TOML parser intentionally supports the manifest subset emitted by
  `to_toml/1`: package metadata, dependency sections, features, strings,
  booleans, arrays of strings, and inline dependency tables. Use
  `add_dependency_to_file/4` and `remove_dependency_from_file/3` when updating an
  existing Cargo.toml because those helpers preserve unrelated sections.
  """

  @default_manifest_path "priv/rust/Cargo.toml"
  @dependency_sections [:dependencies, :dev_dependencies, :build_dependencies]

  @type dependency_source :: :registry | :path | :git

  @type dependency :: %{
          required(:name) => String.t(),
          required(:requirement) => String.t(),
          required(:source) => dependency_source(),
          required(:features) => [String.t()],
          required(:optional?) => boolean(),
          required(:default_features?) => boolean(),
          optional(:path) => String.t() | nil,
          optional(:git) => String.t() | nil,
          optional(:branch) => String.t() | nil,
          optional(:tag) => String.t() | nil,
          optional(:rev) => String.t() | nil
        }

  @type manifest :: %{
          required(:package) => %{String.t() => String.t()},
          required(:dependencies) => %{String.t() => dependency()},
          required(:dev_dependencies) => %{String.t() => dependency()},
          required(:build_dependencies) => %{String.t() => dependency()},
          required(:features) => %{String.t() => [String.t()]}
        }

  @doc """
  Builds a normalized Cargo manifest map.

  Accepted attributes:

    * `:name`, `:version`, `:edition` - package metadata
    * `:package` - additional package metadata
    * `:dependencies`, `:dev_dependencies`, `:build_dependencies`
    * `:features`

  Dependencies can be maps, keyword lists, `{name, requirement}` tuples, or
  explicit dependency maps with a `:name` key.
  """
  @spec manifest(map() | keyword()) :: manifest()
  def manifest(attrs \\ []) do
    attrs = attrs |> Map.new() |> normalize_keys()

    %{
      package:
        %{
          "name" => attrs |> Map.get(:name, "lux_rust") |> safe_package_name(),
          "version" => attrs |> Map.get(:version, "0.1.0") |> to_string(),
          "edition" => attrs |> Map.get(:edition, "2021") |> to_string()
        }
        |> Map.merge(string_map(Map.get(attrs, :package, %{}))),
      dependencies: normalize_dependencies(Map.get(attrs, :dependencies, %{})),
      dev_dependencies: normalize_dependencies(Map.get(attrs, :dev_dependencies, %{})),
      build_dependencies: normalize_dependencies(Map.get(attrs, :build_dependencies, %{})),
      features: normalize_features(Map.get(attrs, :features, %{}))
    }
  end

  @doc """
  Normalizes a Cargo dependency declaration.
  """
  @spec dependency(atom() | String.t(), String.t() | map() | keyword(), keyword()) :: dependency()
  def dependency(name, requirement, opts \\ []) do
    opts = opts |> Map.new() |> normalize_keys()

    {requirement, attrs} =
      cond do
        is_binary(requirement) ->
          {requirement, %{}}

        is_list(requirement) ->
          attrs = requirement |> Map.new() |> normalize_keys()
          {Map.get(attrs, :version, "*"), attrs}

        is_map(requirement) ->
          attrs = normalize_keys(requirement)
          {Map.get(attrs, :version, "*"), attrs}
      end

    attrs = Map.merge(attrs, opts)
    source = dependency_source(attrs)

    %{
      name: to_string(name),
      requirement: requirement |> to_string(),
      source: source,
      path: Map.get(attrs, :path),
      git: Map.get(attrs, :git),
      branch: Map.get(attrs, :branch),
      tag: Map.get(attrs, :tag),
      rev: Map.get(attrs, :rev),
      features: attrs |> Map.get(:features, []) |> List.wrap() |> Enum.map(&to_string/1),
      optional?: Map.get(attrs, :optional, false),
      default_features?:
        Map.get(attrs, :default_features, Map.get(attrs, :default_features?, true))
    }
  end

  @doc """
  Adds or replaces a dependency in a manifest.

  Pass `scope: :dev` for `[dev-dependencies]` or `scope: :build` for
  `[build-dependencies]`. The default scope is regular dependencies.
  """
  @spec add_dependency(manifest(), atom() | String.t(), String.t() | map() | keyword(), keyword()) ::
          manifest()
  def add_dependency(manifest, name, requirement, opts \\ []) do
    {scope, dep_opts} = Keyword.pop(opts, :scope, :dependencies)
    section = dependency_section(scope)
    dep = dependency(name, requirement, dep_opts)
    update_in(manifest, [section], &Map.put(&1, dep.name, dep))
  end

  @doc """
  Removes a dependency from a manifest.
  """
  @spec remove_dependency(manifest(), atom() | String.t(), keyword()) :: manifest()
  def remove_dependency(manifest, name, opts \\ []) do
    section = opts |> Keyword.get(:scope, :dependencies) |> dependency_section()
    update_in(manifest, [section], &Map.delete(&1, to_string(name)))
  end

  @doc """
  Renders a normalized manifest as deterministic Cargo.toml content.
  """
  @spec to_toml(manifest()) :: String.t()
  def to_toml(manifest) do
    [
      render_key_value_section("package", manifest.package),
      render_dependency_section("dependencies", manifest.dependencies),
      render_dependency_section("dev-dependencies", manifest.dev_dependencies),
      render_dependency_section("build-dependencies", manifest.build_dependencies),
      render_features(manifest.features)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  @doc """
  Parses the Cargo.toml subset emitted by `to_toml/1`.

  This is intended for manifests generated by Lux. It does not preserve unknown
  Cargo.toml sections; use the file-level dependency helpers for existing
  projects.
  """
  @spec from_toml(String.t()) :: manifest()
  def from_toml(content) when is_binary(content) do
    {_section, parsed} =
      content
      |> String.split("\n")
      |> Enum.reduce({nil, manifest()}, &parse_toml_line/2)

    parsed
  end

  @doc """
  Reads and parses a Lux-generated Cargo.toml file.

  Unknown Cargo.toml sections are ignored by this parser. Prefer
  `add_dependency_to_file/4` or `remove_dependency_from_file/3` when updating an
  existing manifest that may contain workspace, target, profile, or binary
  sections.
  """
  @spec read_manifest(Path.t()) :: {:ok, manifest()} | {:error, term()}
  def read_manifest(path \\ @default_manifest_path) do
    with {:ok, content} <- File.read(path) do
      {:ok, from_toml(content)}
    end
  end

  @doc """
  Writes a normalized manifest to Cargo.toml.

  This replaces the target file with the deterministic `to_toml/1` output. It is
  safe for manifests generated by Lux, but it is not a preserving TOML rewriter.
  """
  @spec write_manifest(manifest(), Path.t()) :: :ok | {:error, term()}
  def write_manifest(manifest, path \\ @default_manifest_path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()

    File.write(path, to_toml(manifest))
  end

  @doc """
  Adds or replaces one dependency in an existing Cargo.toml file.

  This helper patches only the requested dependency section and leaves unrelated
  sections, comments, and ordering intact. It supports `scope: :dev` for
  `[dev-dependencies]` and `scope: :build` for `[build-dependencies]`.
  """
  @spec add_dependency_to_file(
          Path.t(),
          atom() | String.t(),
          String.t() | map() | keyword(),
          keyword()
        ) ::
          :ok | {:error, term()}
  def add_dependency_to_file(path, name, requirement, opts \\ []) do
    {scope, dep_opts} = Keyword.pop(opts, :scope, :dependencies)
    section = scope |> dependency_section() |> dependency_section_name()
    dep = dependency(name, requirement, dep_opts)

    with {:ok, content} <- File.read(path) do
      File.write(path, patch_dependency_content(content, section, dep))
    end
  end

  @doc """
  Removes one dependency from an existing Cargo.toml file.

  Only the requested dependency section is modified.
  """
  @spec remove_dependency_from_file(Path.t(), atom() | String.t(), keyword()) ::
          :ok | {:error, term()}
  def remove_dependency_from_file(path, name, opts \\ []) do
    section =
      opts
      |> Keyword.get(:scope, :dependencies)
      |> dependency_section()
      |> dependency_section_name()

    with {:ok, content} <- File.read(path) do
      File.write(path, remove_dependency_content(content, section, to_string(name)))
    end
  end

  @doc """
  Creates a minimal Rust Cargo project at `root`.

  The generated project includes `Cargo.toml` and `src/lib.rs`. Existing files
  are left intact unless `force?: true` is provided.
  """
  @spec init_project(Path.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def init_project(root, opts \\ []) do
    opts = opts |> Map.new() |> normalize_keys()
    manifest = opts |> Map.get(:manifest, opts) |> manifest()
    force? = Map.get(opts, :force?, false)
    manifest_path = Path.join(root, "Cargo.toml")
    src_path = Path.join([root, "src", "lib.rs"])

    with :ok <- ensure_writable(manifest_path, force?),
         :ok <- ensure_writable(src_path, force?),
         :ok <- File.mkdir_p(Path.dirname(src_path)),
         :ok <- write_manifest(manifest, manifest_path),
         :ok <- File.write(src_path, Map.get(opts, :lib_rs, default_lib_rs(manifest))) do
      {:ok, %{root: root, manifest_path: manifest_path, src_path: src_path, manifest: manifest}}
    end
  end

  @doc """
  Inspects manifest dependencies against Cargo.lock content and/or an injected
  package version index.

  Options:

    * `:lockfile` - Cargo.lock content or a path to a lockfile
    * `:version_index` - map of package name to available versions

  Path and Git dependencies are considered satisfied without a registry version.
  Registry dependencies are satisfied only when a matching lockfile package or
  version-index entry satisfies the manifest requirement. This is a deterministic
  inspection helper, not a replacement for Cargo's dependency resolver.
  """
  @spec resolve_dependencies(manifest(), keyword() | map()) :: %{String.t() => map()}
  def resolve_dependencies(manifest, opts \\ []) do
    opts = opts |> Map.new() |> normalize_keys()
    lock = opts |> Map.get(:lockfile, "") |> lockfile()
    locked_packages = packages_by_name(lock)
    version_index = Map.get(opts, :version_index, %{}) |> normalize_version_index()

    manifest
    |> all_dependencies()
    |> Map.new(fn {name, dep} ->
      locked =
        dep |> select_locked_package(Map.get(locked_packages, name, [])) |> package_version()

      selected = locked || select_version(dep.requirement, Map.get(version_index, name, []))

      {name,
       %{
         name: name,
         requirement: dep.requirement,
         source: dep.source,
         locked: locked,
         selected: selected,
         satisfied?: dependency_satisfied?(dep, selected)
       }}
    end)
  end

  @doc """
  Finds dependency entries that use the same package name with different
  requirements across dependency sections.
  """
  @spec dependency_conflicts(manifest() | list() | map()) :: [map()]
  def dependency_conflicts(%{dependencies: _} = manifest) do
    manifest
    |> all_dependencies_with_sections()
    |> Enum.group_by(fn {_section, dep} -> dep.name end)
    |> Enum.flat_map(&conflicts_for_dependency/1)
  end

  def dependency_conflicts(dependencies) when is_map(dependencies) do
    dependencies
    |> normalize_dependencies()
    |> Map.values()
    |> dependency_conflicts()
  end

  def dependency_conflicts(dependencies) when is_list(dependencies) do
    dependencies
    |> Enum.map(&normalize_dependency_entry/1)
    |> Enum.group_by(& &1.name)
    |> Enum.flat_map(fn {name, deps} ->
      requirements = deps |> Enum.map(& &1.requirement) |> Enum.uniq()

      if length(requirements) > 1 do
        [%{name: name, requirements: requirements, sections: []}]
      else
        []
      end
    end)
  end

  @doc """
  Returns outdated registry dependencies based on a lockfile and version index.
  """
  @spec outdated(manifest(), keyword() | map()) :: [map()]
  def outdated(manifest, opts \\ []) do
    opts = opts |> Map.new() |> normalize_keys()
    lock = opts |> Map.get(:lockfile, "") |> lockfile()
    locked_packages = packages_by_name(lock)
    version_index = opts |> Map.get(:version_index, %{}) |> normalize_version_index()

    manifest
    |> all_dependencies()
    |> Enum.flat_map(fn {name, dep} ->
      locked =
        dep |> select_locked_package(Map.get(locked_packages, name, [])) |> package_version()

      latest = select_version(dep.requirement, Map.get(version_index, name, []))

      if (dep.source == :registry and locked) && latest && version_gte?(latest, locked) &&
           latest != locked do
        [%{name: name, current: locked, latest: latest, requirement: dep.requirement}]
      else
        []
      end
    end)
  end

  @doc """
  Selects the highest available version matching a Cargo-style requirement
  subset.

  Supported requirement forms include `*`, exact versions, caret requirements
  like `^1.2.3`, compatible bare versions like `1.2`, tilde requirements like
  `~1.2` or `~> 1.2`, and simple comparisons such as `>= 1.2.0`.
  """
  @spec select_version(String.t(), [String.t()]) :: String.t() | nil
  def select_version(requirement, versions) do
    versions
    |> Enum.map(&to_string/1)
    |> Enum.filter(&version_satisfies?(&1, requirement))
    |> Enum.sort(&version_gte?/2)
    |> List.first()
  end

  @doc """
  Parses Cargo.lock package entries.
  """
  @spec parse_lock(String.t()) :: %{
          package_count: non_neg_integer(),
          packages: [map()],
          checksums: [String.t()]
        }
  def parse_lock(content) when is_binary(content) do
    packages =
      Regex.scan(~r/\[\[package\]\]\n(?<body>(?:[^\[]|\[(?!\[package\]\]))*)/m, content,
        capture: :all_names
      )
      |> Enum.map(fn [body] ->
        fields =
          Regex.scan(~r/^([A-Za-z0-9_-]+)\s*=\s*"([^"]*)"/m, body)
          |> Map.new(fn [_line, key, value] -> {key, value} end)

        %{
          name: Map.get(fields, "name"),
          version: Map.get(fields, "version"),
          source: Map.get(fields, "source"),
          checksum: Map.get(fields, "checksum")
        }
      end)
      |> Enum.reject(&is_nil(&1.name))

    %{
      package_count: length(packages),
      packages: packages,
      checksums: packages |> Enum.map(& &1.checksum) |> Enum.reject(&is_nil/1)
    }
  end

  @doc """
  Builds deterministic Cargo command plans for fetch, build, and test.
  """
  @spec build_plan(keyword() | map()) :: map()
  def build_plan(opts \\ []) do
    opts = opts |> Map.new() |> normalize_keys()
    cargo = Map.get(opts, :cargo, "cargo")
    manifest_path = Map.get(opts, :manifest_path, @default_manifest_path)
    profile = Map.get(opts, :profile, :debug)
    features = opts |> Map.get(:features, []) |> List.wrap() |> Enum.map(&to_string/1)

    base = ["--manifest-path", manifest_path]
    build_flags = build_flags(profile, features, opts)
    fetch_flags = fetch_flags(opts)

    %{
      manifest_path: manifest_path,
      fetch: [cargo, "fetch" | base ++ fetch_flags],
      build: [cargo, "build" | base ++ build_flags],
      test: [cargo, "test" | base ++ build_flags]
    }
  end

  @doc """
  Checks whether Cargo is available in the current environment.
  """
  @spec available?() :: boolean()
  def available? do
    System.find_executable("cargo") != nil
  end

  @doc """
  Returns Cargo and Rust toolchain version information.
  """
  @spec version(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  def version(opts \\ []) do
    opts = opts |> Map.new() |> normalize_keys()
    cargo = Map.get(opts, :cargo, "cargo")
    rustc = Map.get(opts, :rustc, "rustc")

    with {:ok, cargo_version} <- run_tool_version(cargo, ["--version"], opts),
         {:ok, rustc_version} <- run_tool_version(rustc, ["--version"], opts) do
      {:ok,
       %{
         cargo: parse_tool_version(cargo_version),
         rustc: parse_tool_version(rustc_version),
         raw: %{cargo: String.trim(cargo_version), rustc: String.trim(rustc_version)}
       }}
    end
  end

  @doc """
  Runs `cargo build` for the configured manifest.

  Use `dry_run: true` to return the command plan without executing Cargo.
  """
  @spec build(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  def build(opts \\ []) do
    run_planned_command(:build, opts)
  end

  @doc """
  Runs `cargo fetch` for the configured manifest.
  """
  @spec fetch(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  def fetch(opts \\ []) do
    run_planned_command(:fetch, opts)
  end

  @doc """
  Runs `cargo test` for the configured manifest.
  """
  @spec test(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  def test(opts \\ []) do
    run_planned_command(:test, opts)
  end

  @doc """
  Computes cache metadata for Cargo build and registry directories.
  """
  @spec cache_plan(manifest(), keyword() | map()) :: map()
  def cache_plan(manifest, opts \\ []) do
    opts = opts |> Map.new() |> normalize_keys()
    lock = opts |> Map.get(:lockfile, "") |> lockfile()
    root = Map.get(opts, :cache_root, ".lux/cargo")
    key = cache_key(manifest, lock)
    package_name = manifest.package["name"]
    manifest_path = Map.get(opts, :manifest_path, @default_manifest_path)
    project_root = Path.dirname(manifest_path)

    %{
      key: key,
      root: root,
      directory: Path.join(root, key),
      restore_keys: [
        "#{package_name}-#{manifest.package["edition"]}-",
        "#{package_name}-"
      ],
      tracked_paths: [
        manifest_path,
        Path.join(project_root, "Cargo.lock"),
        Path.join(project_root, "target"),
        Path.join(project_root, ".cargo")
      ]
    }
  end

  @doc """
  Creates the cache directory described by `cache_plan/2`.
  """
  @spec prepare_cache(manifest(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def prepare_cache(manifest, opts \\ []) do
    plan = cache_plan(manifest, opts)

    case File.mkdir_p(plan.directory) do
      :ok -> {:ok, plan}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a stable cache key from manifest and lockfile state.
  """
  @spec cache_key(manifest(), map()) :: String.t()
  def cache_key(manifest, lockfile \\ %{checksums: []}) do
    payload =
      %{
        package: manifest.package,
        dependencies: manifest.dependencies,
        dev_dependencies: manifest.dev_dependencies,
        build_dependencies: manifest.build_dependencies,
        features: manifest.features,
        lock_packages: Map.get(lockfile, :packages, []),
        lock_checksums: Map.get(lockfile, :checksums, [])
      }
      |> :erlang.term_to_binary()

    :crypto.hash(:sha256, payload)
    |> Base.encode16(case: :lower)
  end

  defp parse_toml_line(line, {section, manifest}) do
    line =
      line
      |> strip_comment()
      |> String.trim()

    cond do
      line == "" ->
        {section, manifest}

      String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
        {line |> String.trim_leading("[") |> String.trim_trailing("]"), manifest}

      String.contains?(line, "=") ->
        [raw_key, raw_value] = String.split(line, "=", parts: 2)
        key = raw_key |> String.trim() |> String.trim("\"")
        value = raw_value |> String.trim() |> parse_toml_value()
        {section, put_toml_value(manifest, section, key, value)}

      true ->
        {section, manifest}
    end
  end

  defp put_toml_value(manifest, "package", key, value) do
    put_in(manifest, [:package, key], to_string(value))
  end

  defp put_toml_value(manifest, "dependencies", key, value) do
    put_in(manifest, [:dependencies, key], dependency_from_toml(key, value))
  end

  defp put_toml_value(manifest, "dev-dependencies", key, value) do
    put_in(manifest, [:dev_dependencies, key], dependency_from_toml(key, value))
  end

  defp put_toml_value(manifest, "build-dependencies", key, value) do
    put_in(manifest, [:build_dependencies, key], dependency_from_toml(key, value))
  end

  defp put_toml_value(manifest, "features", key, value) do
    put_in(manifest, [:features, key], value |> List.wrap() |> Enum.map(&to_string/1))
  end

  defp put_toml_value(manifest, _section, _key, _value), do: manifest

  defp dependency_from_toml(name, value) when is_binary(value), do: dependency(name, value)

  defp dependency_from_toml(name, value) when is_map(value) do
    dependency(name, value)
  end

  defp patch_dependency_content(content, section, dep) do
    line = "#{dep.name} = #{render_dependency(dep)}"

    content
    |> split_lines()
    |> patch_dependency_lines(section, dep.name, line)
    |> Enum.join("\n")
    |> ensure_trailing_newline()
  end

  defp remove_dependency_content(content, section, name) do
    content
    |> split_lines()
    |> remove_dependency_lines(section, name)
    |> Enum.join("\n")
    |> ensure_trailing_newline()
  end

  defp split_lines(content) do
    case String.trim_trailing(content, "\n") do
      "" -> []
      trimmed -> String.split(trimmed, "\n")
    end
  end

  defp patch_dependency_lines(lines, section, name, line) do
    case dependency_section_bounds(lines, section) do
      nil ->
        append_dependency_section(lines, section, line)

      {start_index, end_index} ->
        section_lines = Enum.slice(lines, start_index + 1, end_index - start_index - 1)
        patched_section = put_dependency_line(section_lines, name, line)

        Enum.take(lines, start_index + 1) ++
          patched_section ++
          Enum.drop(lines, end_index)
    end
  end

  defp remove_dependency_lines(lines, section, name) do
    case dependency_section_bounds(lines, section) do
      nil ->
        lines

      {start_index, end_index} ->
        section_lines = Enum.slice(lines, start_index + 1, end_index - start_index - 1)
        patched_section = Enum.reject(section_lines, &dependency_line?(&1, name))

        Enum.take(lines, start_index + 1) ++
          patched_section ++
          Enum.drop(lines, end_index)
    end
  end

  defp append_dependency_section([], section, line), do: ["[#{section}]", line]

  defp append_dependency_section(lines, section, line) do
    separator = if List.last(lines) == "", do: [], else: [""]
    lines ++ separator ++ ["[#{section}]", line]
  end

  defp put_dependency_line(section_lines, name, line) do
    case Enum.split_while(section_lines, &(not dependency_line?(&1, name))) do
      {_before, []} -> append_dependency_line(section_lines, line)
      {before, [_old | after_lines]} -> before ++ [line] ++ after_lines
    end
  end

  defp append_dependency_line(section_lines, line) do
    {body, trailing_blank_lines} = split_trailing_blank_lines(section_lines)
    body ++ [line] ++ trailing_blank_lines
  end

  defp split_trailing_blank_lines(lines) do
    trailing_count =
      lines
      |> Enum.reverse()
      |> Enum.take_while(&(String.trim(&1) == ""))
      |> length()

    Enum.split(lines, length(lines) - trailing_count)
  end

  defp dependency_section_bounds(lines, section) do
    start_index = Enum.find_index(lines, &section_header?(&1, section))

    if start_index do
      end_index =
        lines
        |> Enum.drop(start_index + 1)
        |> Enum.find_index(&toml_section_header?/1)
        |> case do
          nil -> length(lines)
          relative_index -> start_index + 1 + relative_index
        end

      {start_index, end_index}
    end
  end

  defp section_header?(line, section) do
    line
    |> strip_comment()
    |> String.trim()
    |> Kernel.==("[#{section}]")
  end

  defp toml_section_header?(line) do
    line =
      line
      |> strip_comment()
      |> String.trim()

    String.starts_with?(line, "[") and String.ends_with?(line, "]")
  end

  defp dependency_line?(line, name) do
    line
    |> strip_comment()
    |> String.trim()
    |> String.match?(~r/^#{Regex.escape(name)}\s*=/)
  end

  defp ensure_trailing_newline(content), do: String.trim_trailing(content) <> "\n"

  defp ensure_writable(path, true), do: path |> Path.dirname() |> File.mkdir_p()

  defp ensure_writable(path, false) do
    if File.exists?(path) do
      {:error, {:already_exists, path}}
    else
      path |> Path.dirname() |> File.mkdir_p()
    end
  end

  defp default_lib_rs(manifest) do
    """
    //! Rust support scaffold for #{manifest.package["name"]}.

    pub fn package_name() -> &'static str {
        "#{manifest.package["name"]}"
    }
    """
  end

  defp parse_toml_value(value) do
    cond do
      String.starts_with?(value, "\"") ->
        value |> String.trim("\"")

      value in ["true", "false"] ->
        value == "true"

      String.starts_with?(value, "[") ->
        value
        |> String.trim_leading("[")
        |> String.trim_trailing("]")
        |> split_toml_items()
        |> Enum.map(&parse_toml_value/1)

      String.starts_with?(value, "{") ->
        value
        |> String.trim_leading("{")
        |> String.trim_trailing("}")
        |> split_toml_items()
        |> Map.new(fn item ->
          [key, raw] = String.split(item, "=", parts: 2)
          normalized_key = key |> String.trim() |> normalize_key()
          {normalized_key, raw |> String.trim() |> parse_toml_value()}
        end)

      true ->
        value
    end
  end

  defp split_toml_items(content) do
    content
    |> String.graphemes()
    |> Enum.reduce({[], "", false, 0}, fn char, {items, current, in_string?, depth} ->
      cond do
        char == "\"" ->
          {items, current <> char, not in_string?, depth}

        char in ["[", "{"] and not in_string? ->
          {items, current <> char, in_string?, depth + 1}

        char in ["]", "}"] and not in_string? ->
          {items, current <> char, in_string?, max(depth - 1, 0)}

        char == "," and not in_string? and depth == 0 ->
          {[String.trim(current) | items], "", in_string?, depth}

        true ->
          {items, current <> char, in_string?, depth}
      end
    end)
    |> then(fn {items, current, _in_string?, _depth} -> [String.trim(current) | items] end)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp strip_comment(line) do
    line
    |> String.graphemes()
    |> Enum.reduce_while({"", false}, fn char, {acc, in_string?} ->
      cond do
        char == "\"" -> {:cont, {acc <> char, not in_string?}}
        char == "#" and not in_string? -> {:halt, {acc, in_string?}}
        true -> {:cont, {acc <> char, in_string?}}
      end
    end)
    |> elem(0)
  end

  defp render_key_value_section(name, values) do
    body =
      values
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map_join("\n", fn {key, value} -> "#{key} = #{toml_value(value)}" end)

    "[#{name}]\n#{body}"
  end

  defp render_dependency_section(_name, dependencies) when map_size(dependencies) == 0, do: ""

  defp render_dependency_section(name, dependencies) do
    body =
      dependencies
      |> Enum.sort_by(fn {dep_name, _dep} -> dep_name end)
      |> Enum.map_join("\n", fn {dep_name, dep} -> "#{dep_name} = #{render_dependency(dep)}" end)

    "[#{name}]\n#{body}"
  end

  defp render_dependency(
         %{
           source: :registry,
           features: [],
           optional?: false,
           default_features?: true
         } = dep
       ) do
    toml_value(dep.requirement)
  end

  defp render_dependency(dep) do
    []
    |> maybe_pair("version", dep.source == :registry, dep.requirement)
    |> maybe_pair("path", dep.source == :path, dep.path)
    |> maybe_pair("git", dep.source == :git, dep.git)
    |> maybe_pair("branch", dep.branch)
    |> maybe_pair("tag", dep.tag)
    |> maybe_pair("rev", dep.rev)
    |> maybe_pair("features", dep.features != [], dep.features)
    |> maybe_pair("optional", dep.optional?, dep.optional?)
    |> maybe_pair("default-features", dep.default_features? == false, false)
    |> Enum.map_join(", ", fn {key, value} -> "#{key} = #{toml_value(value)}" end)
    |> then(&"{ #{&1} }")
  end

  defp render_features(features) when map_size(features) == 0, do: ""

  defp render_features(features) do
    body =
      features
      |> Enum.sort_by(fn {name, _values} -> name end)
      |> Enum.map_join("\n", fn {name, values} -> "#{name} = #{toml_value(values)}" end)

    "[features]\n#{body}"
  end

  defp toml_value(value) when is_binary(value), do: inspect(value)
  defp toml_value(value) when is_boolean(value), do: to_string(value)
  defp toml_value(value) when is_list(value), do: "[#{Enum.map_join(value, ", ", &toml_value/1)}]"

  defp maybe_pair(attrs, _key, false, _value), do: attrs
  defp maybe_pair(attrs, _key, nil, _value), do: attrs
  defp maybe_pair(attrs, key, true, value), do: attrs ++ [{key, value}]
  defp maybe_pair(attrs, key, _condition, value), do: attrs ++ [{key, value}]
  defp maybe_pair(attrs, key, value), do: maybe_pair(attrs, key, value, value)

  defp normalize_dependencies(dependencies) when is_map(dependencies) do
    dependencies
    |> Enum.map(fn {name, req} -> dependency(name, req) end)
    |> Map.new(&{&1.name, &1})
  end

  defp normalize_dependencies(dependencies) when is_list(dependencies) do
    dependencies
    |> Enum.map(&normalize_dependency_entry/1)
    |> Map.new(&{&1.name, &1})
  end

  defp normalize_dependency_entry(%{name: name} = dep) do
    dep = normalize_keys(dep)
    dependency(name, Map.get(dep, :requirement, Map.get(dep, :version, "*")), dep)
  end

  defp normalize_dependency_entry({name, req}), do: dependency(name, req)
  defp normalize_dependency_entry([name, req]), do: dependency(name, req)

  defp normalize_features(features) when is_map(features) do
    Map.new(features, fn {name, values} ->
      {to_string(name), values |> List.wrap() |> Enum.map(&to_string/1)}
    end)
  end

  defp string_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        {normalize_key(key), value}

      {key, value} ->
        {key, value}
    end)
  end

  defp normalize_key(key) do
    case String.replace(key, "-", "_") do
      "build_dependencies" -> :build_dependencies
      "cache_root" -> :cache_root
      "cargo" -> :cargo
      "cd" -> :cd
      "default_features" -> :default_features
      "dependencies" -> :dependencies
      "dev_dependencies" -> :dev_dependencies
      "dry_run" -> :dry_run
      "edition" -> :edition
      "env" -> :env
      "features" -> :features
      "force?" -> :force?
      "git" -> :git
      "lib_rs" -> :lib_rs
      "locked?" -> :locked?
      "lockfile" -> :lockfile
      "manifest" -> :manifest
      "manifest_path" -> :manifest_path
      "name" -> :name
      "offline?" -> :offline?
      "optional" -> :optional
      "package" -> :package
      "path" -> :path
      "profile" -> :profile
      "requirement" -> :requirement
      "rev" -> :rev
      "rustc" -> :rustc
      "tag" -> :tag
      "target" -> :target
      "version" -> :version
      "version_index" -> :version_index
      other -> other
    end
  end

  defp dependency_source(%{path: path}) when is_binary(path), do: :path
  defp dependency_source(%{git: git}) when is_binary(git), do: :git
  defp dependency_source(_attrs), do: :registry

  defp dependency_section(:dependencies), do: :dependencies
  defp dependency_section(:dependency), do: :dependencies
  defp dependency_section(:runtime), do: :dependencies
  defp dependency_section(:dev), do: :dev_dependencies
  defp dependency_section(:dev_dependencies), do: :dev_dependencies
  defp dependency_section(:build), do: :build_dependencies
  defp dependency_section(:build_dependencies), do: :build_dependencies

  defp dependency_section_name(:dependencies), do: "dependencies"
  defp dependency_section_name(:dev_dependencies), do: "dev-dependencies"
  defp dependency_section_name(:build_dependencies), do: "build-dependencies"

  defp safe_package_name(name) do
    name
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/, "_")
    |> String.trim("_")
    |> case do
      "" -> "lux_rust"
      value -> value
    end
  end

  defp all_dependencies(manifest) do
    manifest.dependencies
    |> Map.merge(manifest.dev_dependencies, fn _name, dep, _dev_dep -> dep end)
    |> Map.merge(manifest.build_dependencies, fn _name, dep, _build_dep -> dep end)
  end

  defp all_dependencies_with_sections(manifest) do
    Enum.flat_map(@dependency_sections, fn section ->
      manifest
      |> Map.fetch!(section)
      |> Enum.map(fn {_name, dep} -> {section, dep} end)
    end)
  end

  defp conflicts_for_dependency({name, sectioned_deps}) do
    requirements =
      sectioned_deps
      |> Enum.map(fn {_section, dep} -> dep.requirement end)
      |> Enum.uniq()

    if length(requirements) > 1 do
      sections = Enum.map(sectioned_deps, fn {section, _dep} -> section end)
      [%{name: name, requirements: requirements, sections: Enum.uniq(sections)}]
    else
      []
    end
  end

  defp packages_by_name(lock) do
    lock.packages
    |> Enum.filter(&(&1.name && &1.version))
    |> Enum.group_by(& &1.name)
  end

  defp select_locked_package(%{source: :registry} = dep, packages) do
    Enum.find(packages, fn package ->
      registry_package?(package) and version_satisfies?(package.version, dep.requirement)
    end)
  end

  defp select_locked_package(%{source: :git} = dep, packages) do
    Enum.find(packages, fn package ->
      source = package.source || ""

      (version_satisfies?(package.version, dep.requirement) and
         dep.git) &&
        String.contains?(source, dep.git)
    end)
  end

  defp select_locked_package(%{source: :path}, _packages), do: nil
  defp package_version(nil), do: nil
  defp package_version(package), do: package.version

  defp registry_package?(package) do
    package.source
    |> to_string()
    |> String.starts_with?("registry+")
  end

  defp lockfile(path) when is_binary(path) do
    cond do
      path == "" ->
        parse_lock("")

      File.regular?(path) ->
        path |> File.read!() |> parse_lock()

      true ->
        parse_lock(path)
    end
  end

  defp lockfile(lock) when is_map(lock), do: lock
  defp lockfile(_lock), do: parse_lock("")

  defp normalize_version_index(index) do
    Map.new(index, fn {name, versions} ->
      {to_string(name), versions |> List.wrap() |> Enum.map(&to_string/1)}
    end)
  end

  defp dependency_satisfied?(%{source: source}, _selected) when source in [:path, :git], do: true
  defp dependency_satisfied?(_dep, selected), do: not is_nil(selected)

  defp version_satisfies?(version, requirement) do
    with {:ok, parsed_version} <- parse_version(version) do
      requirement
      |> to_string()
      |> String.trim()
      |> do_version_satisfies?(parsed_version)
    else
      :error -> false
    end
  end

  defp do_version_satisfies?("", _version), do: true
  defp do_version_satisfies?("*", _version), do: true

  defp do_version_satisfies?(">=" <> required, version) do
    compare_requirement(version, required, [:gt, :eq])
  end

  defp do_version_satisfies?("<=" <> required, version) do
    compare_requirement(version, required, [:lt, :eq])
  end

  defp do_version_satisfies?(">" <> required, version) do
    compare_requirement(version, required, [:gt])
  end

  defp do_version_satisfies?("<" <> required, version) do
    compare_requirement(version, required, [:lt])
  end

  defp do_version_satisfies?("^" <> required, version) do
    compatible_with?(version, required)
  end

  defp do_version_satisfies?("~>" <> required, version) do
    tilde_with?(version, required)
  end

  defp do_version_satisfies?("~" <> required, version) do
    tilde_with?(version, required)
  end

  defp do_version_satisfies?(required, version) do
    if String.match?(required, ~r/^\d+(\.\d+){0,2}$/) do
      compatible_with?(version, required)
    else
      compare_requirement(version, required, [:eq])
    end
  end

  defp compare_requirement(version, required, allowed) do
    with {:ok, required_version} <- parse_version(required) do
      Version.compare(version, required_version) in allowed
    else
      :error -> false
    end
  end

  defp compatible_with?(version, required) do
    with {:ok, base} <- parse_version(required),
         {:ok, upper} <- compatible_upper_bound(base) do
      Version.compare(version, base) in [:gt, :eq] and Version.compare(version, upper) == :lt
    else
      :error -> false
    end
  end

  defp tilde_with?(version, required) do
    segments = required |> String.trim() |> String.split(".")

    with {:ok, base} <- parse_version(required),
         {:ok, upper} <- tilde_upper_bound(base, length(segments)) do
      Version.compare(version, base) in [:gt, :eq] and Version.compare(version, upper) == :lt
    else
      :error -> false
    end
  end

  defp compatible_upper_bound(%Version{major: major, minor: minor, patch: patch}) do
    cond do
      major > 0 -> parse_version("#{major + 1}.0.0")
      minor > 0 -> parse_version("0.#{minor + 1}.0")
      true -> parse_version("0.0.#{patch + 1}")
    end
  end

  defp tilde_upper_bound(%Version{major: major}, segment_count) when segment_count <= 1 do
    parse_version("#{major + 1}.0.0")
  end

  defp tilde_upper_bound(%Version{major: major, minor: minor}, _segment_count) do
    parse_version("#{major}.#{minor + 1}.0")
  end

  defp parse_version(value) do
    value =
      value
      |> to_string()
      |> String.trim()
      |> String.trim_leading("=")
      |> pad_version()

    case Version.parse(value) do
      {:ok, version} -> {:ok, version}
      :error -> :error
    end
  end

  defp pad_version(version) do
    segments = String.split(version, ".")

    cond do
      length(segments) == 1 -> version <> ".0.0"
      length(segments) == 2 -> version <> ".0"
      true -> version
    end
  end

  defp version_gte?(left, right) do
    with {:ok, left} <- parse_version(left),
         {:ok, right} <- parse_version(right) do
      Version.compare(left, right) in [:gt, :eq]
    else
      :error -> false
    end
  end

  defp build_flags(profile, features, opts) do
    manifest_path = Map.get(opts, :manifest_path, @default_manifest_path)

    []
    |> maybe_append(profile == :release, "--release")
    |> maybe_append(locked_flag?(opts, manifest_path), "--locked")
    |> maybe_append(Map.get(opts, :offline?, false), "--offline")
    |> maybe_append(Map.get(opts, :target), ["--target", Map.get(opts, :target)])
    |> maybe_append(features != [], ["--features", Enum.join(features, ",")])
  end

  defp fetch_flags(opts) do
    manifest_path = Map.get(opts, :manifest_path, @default_manifest_path)

    []
    |> maybe_append(locked_flag?(opts, manifest_path), "--locked")
    |> maybe_append(Map.get(opts, :offline?, false), "--offline")
  end

  defp locked_flag?(opts, manifest_path) do
    case Map.get(opts, :locked?, :auto) do
      :auto -> manifest_path |> lockfile_path_for_manifest(Map.get(opts, :cd)) |> File.regular?()
      value -> value
    end
  end

  defp lockfile_path_for_manifest(manifest_path, nil) do
    manifest_path
    |> Path.dirname()
    |> Path.join("Cargo.lock")
  end

  defp lockfile_path_for_manifest(manifest_path, cd) do
    manifest_path
    |> lockfile_path_for_manifest(nil)
    |> then(fn lockfile_path ->
      if Path.type(lockfile_path) == :absolute do
        lockfile_path
      else
        Path.join(cd, lockfile_path)
      end
    end)
  end

  defp maybe_append(args, false, _value), do: args
  defp maybe_append(args, nil, _value), do: args
  defp maybe_append(args, true, value) when is_list(value), do: args ++ value
  defp maybe_append(args, true, value), do: args ++ [value]
  defp maybe_append(args, value, append), do: maybe_append(args, not is_nil(value), append)

  defp run_planned_command(command, opts) do
    opts = opts |> Map.new() |> normalize_keys()
    plan = build_plan(opts)
    [cargo, subcommand | args] = Map.fetch!(plan, command)

    if Map.get(opts, :dry_run, false) do
      {:ok, %{command: [cargo, subcommand | args], plan: plan}}
    else
      run_cargo(cargo, [subcommand | args], opts)
    end
  end

  defp run_cargo(cargo, args, opts) do
    cargo_path = System.find_executable(cargo) || cargo

    cmd_opts =
      []
      |> maybe_cmd_opt(:cd, Map.get(opts, :cd))
      |> maybe_cmd_opt(:stderr_to_stdout, true)
      |> maybe_cmd_opt(:env, Map.get(opts, :env))

    case System.cmd(cargo_path, args, cmd_opts) do
      {output, 0} ->
        {:ok, %{command: [cargo | args], output: output}}

      {output, status} ->
        {:error, "cargo exited with status #{status}: #{output}"}
    end
  rescue
    error in ErlangError -> {:error, Exception.message(error)}
  end

  defp run_tool_version(tool, args, opts) do
    tool_path = System.find_executable(tool) || tool

    case System.cmd(tool_path, args, stderr_to_stdout: true, env: Map.get(opts, :env, [])) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, "#{tool} exited with status #{status}: #{output}"}
    end
  rescue
    error in ErlangError -> {:error, Exception.message(error)}
  end

  defp parse_tool_version(output) do
    output
    |> String.split()
    |> Enum.find(&String.match?(&1, ~r/^\d+\.\d+\.\d+/))
  end

  defp maybe_cmd_opt(opts, _key, nil), do: opts
  defp maybe_cmd_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
