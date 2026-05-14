defmodule Lux.Rust.CargoPlanner do
  @moduledoc """
  Deterministic Cargo package-management planning for Lux Rust projects.

  The planner normalizes package metadata, renders and parses the Cargo.toml
  shape it emits, resolves dependency versions from caller-provided version
  indexes, detects duplicate dependency conflicts, summarizes Cargo.lock
  packages, and returns build/cache plans without shelling out to Cargo.
  """

  @coverage [
    :cargo_toml_management,
    :dependency_resolution,
    :build_system_integration,
    :version_management,
    :package_caching
  ]

  @doc "Builds a normalized Cargo package-management plan."
  @spec plan(map() | keyword()) :: map()
  def plan(attrs \\ []) do
    attrs = normalize_keys(Map.new(attrs))
    manifest = manifest(attrs)
    lock = attrs |> Map.get(:lockfile, "") |> parse_lock()
    resolved = resolve_dependencies(manifest, Map.get(attrs, :version_index, %{}))
    conflicts = dependency_conflicts(Map.get(attrs, :dependencies, []))

    %{
      manifest: manifest,
      cargo_toml: to_toml(manifest),
      lockfile: lock,
      resolved_dependencies: resolved,
      conflicts: conflicts,
      build: build_plan(manifest, attrs),
      cache: cache_plan(manifest, lock, attrs),
      coverage: @coverage
    }
  end

  @doc "Normalizes package, dependency, dev-dependency, and feature metadata."
  @spec manifest(map() | keyword()) :: map()
  def manifest(attrs \\ []) do
    attrs = normalize_keys(Map.new(attrs))

    %{
      package:
        %{
          "name" => attrs |> Map.get(:name, "lux_native") |> safe_package_name(),
          "version" => attrs |> Map.get(:version, "0.1.0") |> to_string(),
          "edition" => attrs |> Map.get(:edition, "2021") |> to_string()
        }
        |> Map.merge(string_map(Map.get(attrs, :package, %{}))),
      dependencies: normalize_dependencies(Map.get(attrs, :dependencies, [])),
      dev_dependencies: normalize_dependencies(Map.get(attrs, :dev_dependencies, [])),
      features: normalize_features(Map.get(attrs, :features, %{}))
    }
  end

  @doc "Creates a normalized dependency descriptor."
  @spec dependency(atom() | String.t(), String.t() | map() | keyword(), keyword()) :: map()
  def dependency(name, requirement, opts \\ []) do
    opts = normalize_keys(Map.new(opts))

    {requirement, extra} =
      cond do
        is_binary(requirement) ->
          {requirement, %{}}

        is_list(requirement) ->
          {Map.get(Map.new(requirement), :version, "*"), Map.new(requirement)}

        is_map(requirement) ->
          {Map.get(normalize_keys(requirement), :version, "*"), normalize_keys(requirement)}
      end

    extra = Map.merge(extra, opts)

    %{
      name: to_string(name),
      requirement: to_string(requirement),
      source: source(extra),
      path: Map.get(extra, :path),
      git: Map.get(extra, :git),
      branch: Map.get(extra, :branch),
      tag: Map.get(extra, :tag),
      rev: Map.get(extra, :rev),
      features: extra |> Map.get(:features, []) |> List.wrap() |> Enum.map(&to_string/1),
      optional?: Map.get(extra, :optional, false),
      default_features?: Map.get(extra, :default_features, true)
    }
  end

  @doc "Renders the normalized manifest into deterministic Cargo.toml content."
  @spec to_toml(map()) :: String.t()
  def to_toml(manifest) do
    [
      render_section("package", manifest.package),
      render_dependency_section("dependencies", manifest.dependencies),
      render_dependency_section("dev-dependencies", manifest.dev_dependencies),
      render_features(manifest.features)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  @doc "Parses the Cargo.toml subset emitted by `to_toml/1`."
  @spec from_toml(String.t()) :: map()
  def from_toml(content) when is_binary(content) do
    {_section, parsed} =
      content
      |> String.split("\n")
      |> Enum.reduce({nil, manifest()}, &parse_toml_line/2)

    parsed
  end

  @doc "Selects dependency versions from a package version index."
  @spec resolve_dependencies(map(), map()) :: map()
  def resolve_dependencies(manifest, version_index) do
    all_dependencies =
      manifest.dependencies
      |> Map.merge(manifest.dev_dependencies, fn _name, dep, _dev_dep -> dep end)

    Map.new(all_dependencies, fn {name, dep} ->
      versions = Map.get(version_index, name, [])
      selected = select_version(dep.requirement, versions)

      {name,
       %{
         requirement: dep.requirement,
         selected: selected,
         source: dep.source,
         satisfied?: not is_nil(selected) or dep.source in [:path, :git]
       }}
    end)
  end

  @doc "Finds duplicate dependency entries with incompatible requirements."
  @spec dependency_conflicts(list() | map()) :: [map()]
  def dependency_conflicts(dependencies) when is_map(dependencies) do
    dependencies |> Map.to_list() |> dependency_conflicts()
  end

  def dependency_conflicts(dependencies) when is_list(dependencies) do
    dependencies
    |> Enum.map(&normalize_dependency_entry/1)
    |> Enum.group_by(& &1.name)
    |> Enum.flat_map(fn {name, deps} ->
      requirements = deps |> Enum.map(& &1.requirement) |> Enum.uniq()

      if length(requirements) > 1 do
        [%{name: name, requirements: requirements}]
      else
        []
      end
    end)
  end

  @doc "Returns the highest version that satisfies a small Cargo requirement subset."
  @spec select_version(String.t(), [String.t()]) :: String.t() | nil
  def select_version(requirement, versions) do
    versions
    |> Enum.map(&to_string/1)
    |> Enum.filter(&version_satisfies?(&1, requirement))
    |> Enum.sort(&version_gte?/2)
    |> List.first()
  end

  @doc "Parses package entries from Cargo.lock content."
  @spec parse_lock(String.t()) :: map()
  def parse_lock(content) when is_binary(content) do
    packages =
      Regex.scan(~r/\[\[package\]\]\n(?<body>(?:[^\[]|\[(?!\[package\]\]))*)/m, content,
        capture: :all_names
      )
      |> Enum.map(fn [body] ->
        fields =
          Regex.scan(~r/^([a-zA-Z0-9_-]+)\s*=\s*"([^"]*)"/m, body)
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

  @doc "Builds deterministic Cargo command plans."
  @spec build_plan(map(), map() | keyword()) :: map()
  def build_plan(manifest, opts \\ []) do
    opts = normalize_keys(Map.new(opts))
    cargo = Map.get(opts, :cargo, "cargo")
    manifest_path = Map.get(opts, :manifest_path, "priv/rust/Cargo.toml")
    profile = Map.get(opts, :profile, :debug)

    features =
      opts
      |> Map.get(:build_features, Map.get(opts, :features, []))
      |> build_features()

    locked? = Map.get(opts, :locked?, true)
    offline? = Map.get(opts, :offline?, false)

    base = ["--manifest-path", manifest_path]
    flags = build_flags(profile, features, locked?, offline?)

    %{
      package: manifest.package["name"],
      manifest_path: manifest_path,
      fetch: [cargo, "fetch" | base ++ Enum.filter(["--locked", offline? && "--offline"], & &1)],
      build: [cargo, "build" | base ++ flags],
      test: [cargo, "test" | base ++ flags]
    }
  end

  @doc "Builds package cache metadata from manifest and lockfile state."
  @spec cache_plan(map(), map(), map() | keyword()) :: map()
  def cache_plan(manifest, lockfile \\ %{checksums: []}, opts \\ []) do
    opts = normalize_keys(Map.new(opts))
    root = Map.get(opts, :cache_root, "priv/rust/.cargo-cache")
    key = cache_key(manifest, lockfile)

    %{
      key: key,
      root: root,
      directory: Path.join(root, key),
      restore_prefixes: [
        "#{manifest.package["name"]}-#{manifest.package["edition"]}-",
        "#{manifest.package["name"]}-"
      ],
      tracked_paths: ["Cargo.toml", "Cargo.lock", "src", "target"]
    }
  end

  @doc "Creates a stable package cache key."
  @spec cache_key(map(), map()) :: String.t()
  def cache_key(manifest, lockfile \\ %{checksums: []}) do
    payload =
      %{
        package: manifest.package,
        dependencies: manifest.dependencies,
        dev_dependencies: manifest.dev_dependencies,
        features: manifest.features,
        lock_checksums: Map.get(lockfile, :checksums, [])
      }
      |> :erlang.term_to_binary()

    :crypto.hash(:sha256, payload)
    |> Base.encode16(case: :lower)
  end

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

  defp source(%{path: path}) when is_binary(path), do: :path
  defp source(%{git: git}) when is_binary(git), do: :git
  defp source(_extra), do: :registry

  defp render_section(name, values) do
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
      |> Enum.map_join("\n", fn {dep_name, dep} ->
        "#{dep_name} = #{render_dependency(dep)}"
      end)

    "[#{name}]\n#{body}"
  end

  defp render_dependency(
         %{source: :registry, features: [], optional?: false, default_features?: true} = dep
       ),
       do: toml_value(dep.requirement)

  defp render_dependency(dep) do
    attrs =
      []
      |> maybe_pair("version", dep.source == :registry, dep.requirement)
      |> maybe_pair("path", dep.source == :path, dep.path)
      |> maybe_pair("git", dep.source == :git, dep.git)
      |> maybe_pair("branch", dep.branch, dep.branch)
      |> maybe_pair("tag", dep.tag, dep.tag)
      |> maybe_pair("rev", dep.rev, dep.rev)
      |> maybe_pair("features", dep.features != [], dep.features)
      |> maybe_pair("optional", dep.optional?, dep.optional?)
      |> maybe_pair("default-features", dep.default_features? == false, false)

    "{ #{Enum.map_join(attrs, ", ", fn {key, value} -> "#{key} = #{toml_value(value)}" end)} }"
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

  defp parse_toml_line(line, {section, manifest}) do
    line = line |> String.trim() |> String.split("#", parts: 2) |> hd() |> String.trim()

    cond do
      line == "" ->
        {section, manifest}

      String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
        {line |> String.trim_leading("[") |> String.trim_trailing("]"), manifest}

      String.contains?(line, "=") ->
        [key, raw_value] = String.split(line, "=", parts: 2)

        apply_toml_value(
          section,
          String.trim(key),
          parse_toml_value(String.trim(raw_value)),
          manifest
        )

      true ->
        {section, manifest}
    end
  end

  defp apply_toml_value("package", key, value, manifest) do
    {"package", %{manifest | package: Map.put(manifest.package, key, value)}}
  end

  defp apply_toml_value("dependencies", key, value, manifest) do
    dep = dependency(key, parsed_dependency_requirement(value), parsed_dependency_opts(value))
    {"dependencies", %{manifest | dependencies: Map.put(manifest.dependencies, key, dep)}}
  end

  defp apply_toml_value("dev-dependencies", key, value, manifest) do
    dep = dependency(key, parsed_dependency_requirement(value), parsed_dependency_opts(value))

    {"dev-dependencies",
     %{manifest | dev_dependencies: Map.put(manifest.dev_dependencies, key, dep)}}
  end

  defp apply_toml_value("features", key, value, manifest) do
    {"features", %{manifest | features: Map.put(manifest.features, key, List.wrap(value))}}
  end

  defp apply_toml_value(section, _key, _value, manifest), do: {section, manifest}

  defp parse_toml_value("\"" <> rest), do: String.trim_trailing(rest, "\"")
  defp parse_toml_value("true"), do: true
  defp parse_toml_value("false"), do: false

  defp parse_toml_value("[" <> rest) do
    rest
    |> String.trim_trailing("]")
    |> split_csv()
    |> Enum.map(&parse_toml_value/1)
  end

  defp parse_toml_value("{" <> rest) do
    rest
    |> String.trim_trailing("}")
    |> split_csv()
    |> Map.new(fn pair ->
      [key, value] = String.split(pair, "=", parts: 2)

      {key |> String.trim() |> String.replace("-", "_") |> known_key(),
       value |> String.trim() |> parse_toml_value()}
    end)
  end

  defp parse_toml_value(value), do: value

  defp parsed_dependency_requirement(value) when is_binary(value), do: value
  defp parsed_dependency_requirement(value) when is_map(value), do: Map.get(value, :version, "*")

  defp parsed_dependency_opts(value) when is_binary(value), do: []
  defp parsed_dependency_opts(value) when is_map(value), do: Map.to_list(value)

  defp split_csv(""), do: []

  defp split_csv(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp build_flags(profile, features, locked?, offline?) do
    []
    |> maybe_flag(locked?, "--locked")
    |> maybe_flag(offline?, "--offline")
    |> maybe_flag(profile == :release or profile == "release", "--release")
    |> maybe_feature_flags(features)
  end

  defp maybe_feature_flags(flags, []), do: flags
  defp maybe_feature_flags(flags, features), do: flags ++ ["--features", Enum.join(features, ",")]

  defp maybe_flag(flags, true, flag), do: flags ++ [flag]
  defp maybe_flag(flags, _condition, _flag), do: flags

  defp maybe_pair(attrs, _key, false, _value), do: attrs
  defp maybe_pair(attrs, _key, nil, _value), do: attrs
  defp maybe_pair(attrs, key, _condition, value), do: attrs ++ [{key, value}]

  defp version_satisfies?(_version, "*"), do: true
  defp version_satisfies?(version, requirement) when version == requirement, do: true

  defp version_satisfies?(version, "~> " <> base),
    do: same_major_minor_or_newer_patch?(version, base)

  defp version_satisfies?(version, "^" <> base), do: caret_compatible?(version, base)

  defp version_satisfies?(version, requirement) do
    cond do
      Regex.match?(~r/^\d+$/, requirement) ->
        major(version) == String.to_integer(requirement)

      Regex.match?(~r/^\d+\.\d+$/, requirement) ->
        major_minor(version) == major_minor(requirement)

      true ->
        false
    end
  end

  defp same_major_minor_or_newer_patch?(version, base) do
    major_minor(version) == major_minor(base) and version_gte?(version, normalize_version(base))
  end

  defp same_major?(version, base), do: major(version) == major(base)

  defp caret_compatible?(version, base) do
    if major(base) == 0 do
      major_minor(version) == major_minor(base)
    else
      same_major?(version, base)
    end
  end

  defp version_gte?(left, right) do
    compare_versions(left, right) in [:gt, :eq]
  end

  defp compare_versions(left, right) do
    left_parts = version_parts(left)
    right_parts = version_parts(right)

    cond do
      left_parts > right_parts -> :gt
      left_parts < right_parts -> :lt
      true -> :eq
    end
  end

  defp version_parts(version) do
    version
    |> normalize_version()
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
  end

  defp normalize_version(version) do
    parts = version |> to_string() |> String.split(".")
    (parts ++ List.duplicate("0", 3)) |> Enum.take(3) |> Enum.join(".")
  end

  defp major(version), do: version |> version_parts() |> hd()
  defp major_minor(version), do: version |> version_parts() |> Enum.take(2)

  defp safe_package_name(name) do
    name
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
  end

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {key |> String.replace("-", "_") |> known_key(), value}
      {key, value} -> {key, value}
    end)
  end

  defp build_features(values) when is_map(values), do: []

  defp build_features(values) do
    values
    |> List.wrap()
    |> Enum.map(&to_string/1)
  end

  defp known_key("name"), do: :name
  defp known_key("version"), do: :version
  defp known_key("edition"), do: :edition
  defp known_key("package"), do: :package
  defp known_key("dependencies"), do: :dependencies
  defp known_key("dev_dependencies"), do: :dev_dependencies
  defp known_key("features"), do: :features
  defp known_key("lockfile"), do: :lockfile
  defp known_key("version_index"), do: :version_index
  defp known_key("cargo"), do: :cargo
  defp known_key("manifest_path"), do: :manifest_path
  defp known_key("profile"), do: :profile
  defp known_key("locked?"), do: :locked?
  defp known_key("locked"), do: :locked?
  defp known_key("offline?"), do: :offline?
  defp known_key("offline"), do: :offline?
  defp known_key("cache_root"), do: :cache_root
  defp known_key("build_features"), do: :build_features
  defp known_key("path"), do: :path
  defp known_key("git"), do: :git
  defp known_key("branch"), do: :branch
  defp known_key("tag"), do: :tag
  defp known_key("rev"), do: :rev
  defp known_key("optional"), do: :optional
  defp known_key("default_features"), do: :default_features
  defp known_key("requirement"), do: :requirement
  defp known_key(key), do: key
end
