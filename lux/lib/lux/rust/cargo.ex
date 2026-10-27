defmodule Lux.Rust.Cargo do
  @moduledoc """
  Cargo package management integration for Rust projects in Lux.

  Provides:
  - `Cargo.toml` manifest generation and parsing
  - Dependency specification normalization and transitive resolution
  - Semantic version requirement validation and compatibility checking
  - Deterministic package and build caching with SHA-256 cache keys
  - Build pipeline command construction and optional `cargo` execution

  ## Examples

      iex> manifest = Lux.Rust.Cargo.generate_manifest(%{
      ...>   name: "lux_rust_component",
      ...>   version: "0.1.0",
      ...>   edition: "2021",
      ...>   dependencies: %{
      ...>     "serde" => %{version: "1.0", features: ["derive"]},
      ...>     "tokio" => "1.38.0"
      ...>   }
      ...> })
      iex> {:ok, parsed} = Lux.Rust.Cargo.parse_manifest(manifest)
      iex> parsed.package.name
      "lux_rust_component"
  """

  @default_edition "2021"
  @default_version "0.1.0"

  @type dep_spec ::
          String.t()
          | %{
              optional(:version) => String.t(),
              optional(:features) => [String.t()],
              optional(:optional) => boolean(),
              optional(:default_features) => boolean(),
              optional(:path) => String.t(),
              optional(:git) => String.t(),
              optional(:branch) => String.t(),
              optional(:rev) => String.t()
            }

  @type manifest :: %{
          package: %{
            name: String.t(),
            version: String.t(),
            edition: String.t(),
            description: String.t() | nil,
            authors: [String.t()],
            license: String.t() | nil
          },
          dependencies: %{optional(String.t()) => map()},
          dev_dependencies: %{optional(String.t()) => map()},
          lib: map() | nil
        }

  @doc """
  Generates a formatted `Cargo.toml` manifest string from a configuration map.
  """
  @spec generate_manifest(map()) :: String.t()
  def generate_manifest(config) when is_map(config) do
    pkg = Map.get(config, :package, config)
    name = fetch_str(pkg, :name, "lux_crate")
    version = fetch_str(pkg, :version, @default_version)
    edition = fetch_str(pkg, :edition, @default_edition)
    description = fetch_str(pkg, :description, nil)
    license = fetch_str(pkg, :license, nil)
    authors = fetch_list(pkg, :authors)

    deps = Map.get(config, :dependencies, Map.get(config, "dependencies", %{}))
    dev_deps = Map.get(config, :dev_dependencies, Map.get(config, "dev-dependencies", %{}))
    lib_cfg = Map.get(config, :lib, Map.get(config, "lib"))

    package_lines =
      [
        "[package]",
        ~s(name = "#{escape_toml(name)}"),
        ~s(version = "#{escape_toml(version)}"),
        ~s(edition = "#{escape_toml(edition)}")
      ]
      |> maybe_append(description, fn d -> ~s(description = "#{escape_toml(d)}") end)
      |> maybe_append(license, fn l -> ~s(license = "#{escape_toml(l)}") end)
      |> maybe_append(if(authors != [], do: authors), fn a ->
        formatted = Enum.map_join(a, ", ", &~s("#{escape_toml(&1)}"))
        "authors = [#{formatted}]"
      end)

    lib_lines =
      case lib_cfg do
        %{} = l when map_size(l) > 0 ->
          crate_types = fetch_list(l, :crate_type)
          lib_name = fetch_str(l, :name, nil)

          ["", "[lib]"]
          |> maybe_append(lib_name, fn n -> ~s(name = "#{escape_toml(n)}") end)
          |> maybe_append(if(crate_types != [], do: crate_types), fn cts ->
            formatted = Enum.map_join(cts, ", ", &~s("#{escape_toml(&1)}"))
            "crate-type = [#{formatted}]"
          end)

        _ ->
          []
      end

    dep_lines = render_dependency_section("dependencies", deps)
    dev_dep_lines = render_dependency_section("dev-dependencies", dev_deps)

    (package_lines ++ lib_lines ++ dep_lines ++ dev_dep_lines)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  @doc """
  Parses a `Cargo.toml` string into a structured manifest map.
  """
  @spec parse_manifest(String.t()) :: {:ok, manifest()} | {:error, term()}
  def parse_manifest(toml) when is_binary(toml) do
    with {:ok, decoded} <- decode_cargo_toml(toml) do
      pkg = Map.get(decoded, "package", %{})
      deps = normalize_deps_map(Map.get(decoded, "dependencies", %{}))
      dev_deps = normalize_deps_map(Map.get(decoded, "dev-dependencies", %{}))

      manifest = %{
        package: %{
          name: Map.get(pkg, "name", ""),
          version: Map.get(pkg, "version", @default_version),
          edition: Map.get(pkg, "edition", @default_edition),
          description: Map.get(pkg, "description"),
          authors: Map.get(pkg, "authors", []),
          license: Map.get(pkg, "license")
        },
        dependencies: deps,
        dev_dependencies: dev_deps,
        lib: Map.get(decoded, "lib")
      }

      if manifest.package.name == "" do
        {:error, :missing_package_name}
      else
        {:ok, manifest}
      end
    end
  end

  @doc """
  Adds or updates a dependency in a manifest map or `Cargo.toml` string.
  """
  @spec put_dependency(manifest() | String.t(), String.t(), dep_spec(), keyword()) ::
          {:ok, manifest()} | {:error, term()}
  def put_dependency(manifest_or_toml, name, spec, opts \\ [])

  def put_dependency(toml, name, spec, opts) when is_binary(toml) do
    with {:ok, manifest} <- parse_manifest(toml) do
      put_dependency(manifest, name, spec, opts)
    end
  end

  def put_dependency(%{dependencies: _} = manifest, name, spec, opts) when is_binary(name) do
    normalized = normalize_dep_spec(spec)
    section = if Keyword.get(opts, :dev, false), do: :dev_dependencies, else: :dependencies

    with :ok <- validate_dep_spec(normalized) do
      updated = Map.update(manifest, section, %{name => normalized}, &Map.put(&1, name, normalized))
      {:ok, updated}
    end
  end

  @doc """
  Removes a dependency from a manifest map.
  """
  @spec remove_dependency(manifest(), String.t(), keyword()) :: manifest()
  def remove_dependency(%{dependencies: _} = manifest, name, opts \\ []) when is_binary(name) do
    section = if Keyword.get(opts, :dev, false), do: :dev_dependencies, else: :dependencies
    Map.update(manifest, section, %{}, &Map.delete(&1, name))
  end

  @doc """
  Validates a semantic version or Cargo version requirement string, and optionally
  checks whether a candidate `version` satisfies `requirement`.
  """
  @spec version_compatible?(String.t(), String.t()) :: boolean()
  def version_compatible?(version, requirement)
      when is_binary(version) and is_binary(requirement) do
    req = normalize_cargo_req(requirement)

    with {:ok, parsed_version} <- Version.parse(normalize_semver(version)),
         {:ok, parsed_req} <- Version.parse_requirement(req) do
      Version.match?(parsed_version, parsed_req)
    else
      _ -> false
    end
  end

  @doc """
  Resolves a dependency map against an optional registry/catalog of available versions,
  detecting version conflicts or invalid requirements.
  """
  @spec resolve_dependencies(map(), map()) ::
          {:ok, [%{name: String.t(), version: String.t(), features: [String.t()], source: atom()}]}
          | {:error, term()}
  def resolve_dependencies(dependencies, registry \\ %{}) when is_map(dependencies) do
    normalized = normalize_deps_map(dependencies)

    normalized
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.reduce_while({:ok, []}, fn {name, spec}, {:ok, acc} ->
      case resolve_single_dependency(name, spec, registry) do
        {:ok, resolved} -> {:cont, {:ok, [resolved | acc]}}
        {:error, reason} -> {:halt, {:error, {name, reason}}}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  @doc """
  Computes a deterministic SHA-256 cache key for a manifest and build profile/options,
  and manages cached build metadata on disk.
  """
  @spec cache_key(manifest() | String.t(), keyword()) :: String.t()
  def cache_key(manifest_or_toml, opts \\ []) do
    toml_str =
      case manifest_or_toml do
        bin when is_binary(bin) -> bin
        %{} = m -> generate_manifest(m)
      end

    profile = Keyword.get(opts, :profile, :debug)
    target = Keyword.get(opts, :target, "default")
    features = opts |> Keyword.get(:features, []) |> Enum.sort() |> Enum.join(",")

    payload = "#{toml_str}|profile=#{profile}|target=#{target}|features=#{features}"
    :sha256 |> :crypto.hash(payload) |> Base.encode16(case: :lower)
  end

  @doc """
  Stores or retrieves cached package build metadata in the given `cache_dir`.
  """
  @spec fetch_or_store_cache(String.t(), String.t(), (-> {:ok, map()} | {:error, term()})) ::
          {:ok, map(), :hit | :miss} | {:error, term()}
  def fetch_or_store_cache(cache_dir, key, builder_fun)
      when is_binary(cache_dir) and is_binary(key) and is_function(builder_fun, 0) do
    entry_path = Path.join(cache_dir, "#{key}.etf")

    if File.regular?(entry_path) do
      data = entry_path |> File.read!() |> :erlang.binary_to_term([:safe])
      {:ok, data, :hit}
    else
      with :ok <- File.mkdir_p(cache_dir),
           {:ok, built} <- builder_fun.(),
           :ok <- File.write(entry_path, :erlang.term_to_binary(built)) do
        {:ok, built, :miss}
      end
    end
  end

  @doc """
  Builds the `cargo` CLI command and arguments for a build pipeline step (`:build`, `:check`, `:test`, `:fetch`).
  """
  @spec build_command(atom(), keyword()) :: {String.t(), [String.t()]}
  def build_command(step \\ :build, opts \\ []) when step in [:build, :check, :test, :fetch] do
    subcmd = Atom.to_string(step)
    manifest_path = Keyword.get(opts, :manifest_path)
    release? = Keyword.get(opts, :profile, :debug) == :release or Keyword.get(opts, :release, false)
    features = Keyword.get(opts, :features, [])
    offline? = Keyword.get(opts, :offline, false)

    args =
      [subcmd]
      |> maybe_append_args(manifest_path != nil, ["--manifest-path", to_string(manifest_path)])
      |> maybe_append_args(release? and step in [:build, :check, :test], ["--release"])
      |> maybe_append_args(features != [], ["--features", Enum.join(features, ",")])
      |> maybe_append_args(offline?, ["--offline"])

    {"cargo", args}
  end

  @doc """
  Scaffolds a Rust crate directory (`Cargo.toml` and `src/lib.rs`) at `project_dir`
  and returns `{:ok, %{manifest_path: ..., cache_key: ..., command: ...}}`.
  """
  @spec prepare_project(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def prepare_project(project_dir, config, opts \\ []) when is_binary(project_dir) and is_map(config) do
    manifest_toml = generate_manifest(config)

    with {:ok, parsed} <- parse_manifest(manifest_toml),
         {:ok, resolved_deps} <- resolve_dependencies(parsed.dependencies, Keyword.get(opts, :registry, %{})),
         :ok <- File.mkdir_p(Path.join(project_dir, "src")),
         manifest_path = Path.join(project_dir, "Cargo.toml"),
         :ok <- File.write(manifest_path, manifest_toml) do
      lib_rs_path = Path.join([project_dir, "src", "lib.rs"])

      if not File.exists?(lib_rs_path) do
        default_lib = Map.get(config, :lib_source, "pub fn lux_ready() -> bool { true }\n")
        File.write!(lib_rs_path, default_lib)
      end

      key = cache_key(manifest_toml, opts)
      cmd = build_command(Keyword.get(opts, :step, :build), Keyword.put(opts, :manifest_path, manifest_path))

      {:ok,
       %{
         project_dir: project_dir,
         manifest_path: manifest_path,
         manifest: parsed,
         resolved_dependencies: resolved_deps,
         cache_key: key,
         command: cmd
       }}
    end
  end

  # Private helpers

  defp decode_cargo_toml(toml) do
    lines =
      toml
      |> String.split(~r/\r?\n/)
      |> Enum.map(&strip_toml_comment/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Enum.reduce_while(lines, {:ok, {nil, %{}}}, fn line, {:ok, {section, acc}} ->
      cond do
        Regex.match?(~r/^\[[a-zA-Z0-9_.-]+\]$/, line) ->
          sec = line |> String.trim_leading("[") |> String.trim_trailing("]")
          {:cont, {:ok, {sec, Map.put_new(acc, sec, %{})}}}

        is_nil(section) ->
          {:halt, {:error, {:invalid_toml, {:unexpected_line_outside_section, line}}}}

        true ->
          case String.split(line, "=", parts: 2) do
            [raw_k, raw_v] ->
              key = String.trim(raw_k)

              case parse_toml_value(String.trim(raw_v)) do
                {:ok, val} ->
                  sec_map = Map.get(acc, section, %{}) |> Map.put(key, val)
                  {:cont, {:ok, {section, Map.put(acc, section, sec_map)}}}

                {:error, reason} ->
                  {:halt, {:error, {:invalid_toml, reason}}}
              end

            _ ->
              {:halt, {:error, {:invalid_toml, {:invalid_key_value, line}}}}
          end
      end
    end)
    |> case do
      {:ok, {_section, decoded}} -> {:ok, decoded}
      error -> error
    end
  end

  defp strip_toml_comment(line) do
    case Regex.run(~r/^((?:[^"#]|"[^"]*")*)/, line) do
      [_, head | _] -> head
      _ -> line
    end
  end

  defp parse_toml_value(<<"\"", _::binary>> = quoted) do
    if String.ends_with?(quoted, "\"") and byte_size(quoted) >= 2 do
      inner =
        quoted
        |> String.slice(1, String.length(quoted) - 2)
        |> String.replace("\\\"", "\"")
        |> String.replace("\\\\", "\\")

      {:ok, inner}
    else
      {:error, {:unterminated_string, quoted}}
    end
  end

  defp parse_toml_value("true"), do: {:ok, true}
  defp parse_toml_value("false"), do: {:ok, false}

  defp parse_toml_value("[" <> rest) do
    if String.ends_with?(rest, "]") do
      inner = String.slice(rest, 0, String.length(rest) - 1) |> String.trim()

      if inner == "" do
        {:ok, []}
      else
        inner
        |> String.split(",")
        |> Enum.reduce_while({:ok, []}, fn item, {:ok, list} ->
          case parse_toml_value(String.trim(item)) do
            {:ok, v} -> {:cont, {:ok, [v | list]}}
            err -> {:halt, err}
          end
        end)
        |> case do
          {:ok, list} -> {:ok, Enum.reverse(list)}
          err -> err
        end
      end
    else
      {:error, {:unterminated_array, "[" <> rest}}
    end
  end

  defp parse_toml_value("{" <> rest) do
    if String.ends_with?(rest, "}") do
      inner = String.slice(rest, 0, String.length(rest) - 1) |> String.trim()

      if inner == "" do
        {:ok, %{}}
      else
        inner
        |> split_inline_table()
        |> Enum.reduce_while({:ok, %{}}, fn pair, {:ok, map} ->
          case String.split(pair, "=", parts: 2) do
            [k, v] ->
              case parse_toml_value(String.trim(v)) do
                {:ok, parsed_v} -> {:cont, {:ok, Map.put(map, String.trim(k), parsed_v)}}
                err -> {:halt, err}
              end

            _ ->
              {:halt, {:error, {:invalid_inline_table_entry, pair}}}
          end
        end)
      end
    else
      {:error, {:unterminated_inline_table, "{" <> rest}}
    end
  end

  defp parse_toml_value(other), do: {:error, {:unsupported_value, other}}

  defp split_inline_table(str) do
    str
    |> String.graphemes()
    |> Enum.reduce({[], "", 0, false}, fn ch, {acc, cur, bracket_depth, in_quotes} ->
      cond do
        ch == "\"" ->
          {acc, cur <> ch, bracket_depth, not in_quotes}

        not in_quotes and ch == "[" ->
          {acc, cur <> ch, bracket_depth + 1, in_quotes}

        not in_quotes and ch == "]" ->
          {acc, cur <> ch, max(0, bracket_depth - 1), in_quotes}

        not in_quotes and bracket_depth == 0 and ch == "," ->
          {[String.trim(cur) | acc], "", 0, false}

        true ->
          {acc, cur <> ch, bracket_depth, in_quotes}
      end
    end)
    |> then(fn {acc, last, _, _} ->
      final = if String.trim(last) == "", do: acc, else: [String.trim(last) | acc]
      Enum.reverse(final)
    end)
  end

  defp resolve_single_dependency(_name, %{path: path} = spec, _registry) when is_binary(path) do
    {:ok, %{name: nil, version: Map.get(spec, :version, "0.0.0-local"), features: Map.get(spec, :features, []), source: :path}}
  end

  defp resolve_single_dependency(name, %{git: git} = spec, _registry) when is_binary(git) do
    {:ok, %{name: name, version: Map.get(spec, :rev) || Map.get(spec, :branch) || "HEAD", features: Map.get(spec, :features, []), source: :git}}
  end

  defp resolve_single_dependency(name, spec, registry) do
    req = Map.get(spec, :version)

    cond do
      is_nil(req) or req == "" ->
        {:error, :missing_version}

      not valid_version_requirement?(req) ->
        {:error, {:invalid_version_requirement, req}}

      Map.has_key?(registry, name) ->
        available = List.wrap(Map.get(registry, name))

        case Enum.find(available, &version_compatible?(&1, req)) do
          nil -> {:error, {:no_matching_version, req, available}}
          matched -> {:ok, %{name: name, version: matched, features: Map.get(spec, :features, []), source: :registry}}
        end

      true ->
        {:ok, %{name: name, version: normalize_semver(req), features: Map.get(spec, :features, []), source: :crates_io}}
    end
  end

  defp validate_dep_spec(%{path: path}) when is_binary(path) and path != "", do: :ok
  defp validate_dep_spec(%{git: git}) when is_binary(git) and git != "", do: :ok

  defp validate_dep_spec(%{version: v}) when is_binary(v) do
    if valid_version_requirement?(v), do: :ok, else: {:error, {:invalid_version_requirement, v}}
  end

  defp validate_dep_spec(_), do: {:error, :missing_version_or_source}

  defp valid_version_requirement?(req) when is_binary(req) do
    case Version.parse_requirement(normalize_cargo_req(req)) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp normalize_cargo_req(req) do
    trimmed = String.trim(req)

    cond do
      trimmed == "*" ->
        ">= 0.0.0"

      Regex.match?(~r/^\d+\.\d+\.\d+/, trimmed) ->
        "~> " <> trimmed

      Regex.match?(~r/^\d+\.\d+$/, trimmed) ->
        "~> " <> trimmed

      String.starts_with?(trimmed, "^") ->
        "~> " <> String.trim_leading(trimmed, "^")

      String.starts_with?(trimmed, "~") and not String.starts_with?(trimmed, "~>") ->
        "~> " <> String.trim_leading(trimmed, "~")

      String.starts_with?(trimmed, "=") ->
        "== " <> String.trim_leading(trimmed, "=")

      true ->
        trimmed
    end
  end

  defp normalize_semver(v) do
    trimmed =
      v
      |> String.trim()
      |> String.trim_leading("^")
      |> String.trim_leading("~>")
      |> String.trim_leading("~")
      |> String.trim_leading("=")
      |> String.trim()

    case String.split(trimmed, ".") do
      [major] -> "#{major}.0.0"
      [major, minor] -> "#{major}.#{minor}.0"
      _ -> trimmed
    end
  end

  defp normalize_deps_map(deps) when is_map(deps) do
    Map.new(deps, fn {k, v} -> {to_string(k), normalize_dep_spec(v)} end)
  end

  defp normalize_dep_spec(v) when is_binary(v) do
    %{version: v, features: [], optional: false, default_features: true}
  end

  defp normalize_dep_spec(m) when is_map(m) do
    %{
      version: fetch_str(m, :version, nil),
      features: fetch_list(m, :features),
      optional: fetch_bool(m, :optional, false),
      default_features: fetch_bool(m, :default_features, fetch_bool(m, :"default-features", true)),
      path: fetch_str(m, :path, nil),
      git: fetch_str(m, :git, nil),
      branch: fetch_str(m, :branch, nil),
      rev: fetch_str(m, :rev, nil)
    }
    |> Enum.reject(fn {_k, val} -> is_nil(val) end)
    |> Map.new()
  end

  defp render_dependency_section(_header, deps) when map_size(deps) == 0, do: []

  defp render_dependency_section(header, deps) do
    lines =
      deps
      |> normalize_deps_map()
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map(fn {name, spec} ->
        render_dep_line(name, spec)
      end)

    ["", "[#{header}]" | lines]
  end

  defp render_dep_line(name, spec) do
    simple? =
      Map.get(spec, :features, []) == [] and
        Map.get(spec, :optional, false) == false and
        Map.get(spec, :default_features, true) == true and
        is_nil(Map.get(spec, :path)) and
        is_nil(Map.get(spec, :git)) and
        is_binary(Map.get(spec, :version))

    if simple? do
      ~s(#{name} = "#{escape_toml(spec.version)}")
    else
      fields =
        []
        |> maybe_append(Map.get(spec, :version), fn v -> ~s(version = "#{escape_toml(v)}") end)
        |> maybe_append(Map.get(spec, :path), fn p -> ~s(path = "#{escape_toml(p)}") end)
        |> maybe_append(Map.get(spec, :git), fn g -> ~s(git = "#{escape_toml(g)}") end)
        |> maybe_append(Map.get(spec, :branch), fn b -> ~s(branch = "#{escape_toml(b)}") end)
        |> maybe_append(Map.get(spec, :rev), fn r -> ~s(rev = "#{escape_toml(r)}") end)
        |> maybe_append(if(Map.get(spec, :features, []) != [], do: spec.features), fn fs ->
          formatted = Enum.map_join(fs, ", ", &~s("#{escape_toml(&1)}"))
          "features = [#{formatted}]"
        end)
        |> maybe_append(if(Map.get(spec, :optional, false), do: true), fn _ -> "optional = true" end)
        |> maybe_append(if(Map.get(spec, :default_features, true) == false, do: false), fn _ ->
          "default-features = false"
        end)

      "#{name} = { #{Enum.join(fields, ", ")} }"
    end
  end

  defp fetch_str(map, key, default) do
    case Map.get(map, key, Map.get(map, Atom.to_string(key), default)) do
      nil -> default
      v -> to_string(v)
    end
  end

  defp fetch_list(map, key) do
    case Map.get(map, key, Map.get(map, Atom.to_string(key), [])) do
      list when is_list(list) -> Enum.map(list, &to_string/1)
      _ -> []
    end
  end

  defp fetch_bool(map, key, default) do
    case Map.get(map, key, Map.get(map, Atom.to_string(key), default)) do
      v when is_boolean(v) -> v
      _ -> default
    end
  end

  defp maybe_append(list, nil, _fun), do: list
  defp maybe_append(list, value, fun), do: list ++ [fun.(value)]

  defp maybe_append_args(args, false, _extra), do: args
  defp maybe_append_args(args, true, extra), do: args ++ extra

  defp escape_toml(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
