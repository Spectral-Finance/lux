defmodule Lux.Cargo do
  @moduledoc """
  Cargo package management integration for Lux.

  Provides seamless integration with Rust's Cargo build system, enabling
  `Cargo.toml` management, dependency resolution, build orchestration,
  version management, and crates.io lookups — all from Elixir.

  ## Features

  - **Cargo.toml management**: Parse, modify, and generate `Cargo.toml` files
  - **Dependency management**: Add, remove, and update crate dependencies
  - **Build integration**: `cargo build`, `cargo test`, `cargo check`, `cargo fetch`
  - **Version management**: Query crates.io for latest stable versions
  - **Package caching**: ETS-backed cache for crates.io responses

  ## Quick start

      # Parse an existing Cargo.toml
      {:ok, manifest} = Lux.Cargo.parse_toml("path/to/Cargo.toml")

      # Add serde with the derive feature
      :ok = Lux.Cargo.add_dependency("path/to/Cargo.toml", "serde", "1.0",
                                     features: ["derive"])

      # Build in release mode
      {:ok, _output} = Lux.Cargo.build("path/to/project", release: true)

      # Lookup the latest version of tokio
      {:ok, "1.42.0"} = Lux.Cargo.latest_version("tokio")

  ## Configuration

      config :lux, Lux.Cargo,
        cache_ttl: 3600,          # seconds; 0 to disable (default: 3600)
        crates_io_base: "https://crates.io/api/v1"
  """

  require Logger

  @table :lux_cargo_cache
  @default_cache_ttl 3_600
  @crates_io_base "https://crates.io/api/v1"
  @user_agent "lux-cargo/0.1 (https://github.com/Spectral-Finance/lux)"

  @type path :: String.t()
  @type crate_name :: String.t()
  @type version_string :: String.t()
  @type section :: :dependencies | :dev_dependencies | :build_dependencies

  @type manifest :: %{
          package: %{String.t() => String.t()},
          dependencies: %{String.t() => String.t()},
          dev_dependencies: %{String.t() => String.t()},
          build_dependencies: %{String.t() => String.t()}
        }

  # ── Cargo.toml management ───────────────────────────────────────────────────

  @doc """
  Parses a `Cargo.toml` file into a structured map.

  Only the `[package]`, `[dependencies]`, `[dev-dependencies]`, and
  `[build-dependencies]` sections are extracted; workspace and other
  advanced sections are ignored.

  ## Examples

      iex> Lux.Cargo.parse_toml("/project/Cargo.toml")
      {:ok,
       %{
         package: %{"name" => ~s("my_crate"), "version" => ~s("0.1.0")},
         dependencies: %{"serde" => ~s("1.0")},
         dev_dependencies: %{},
         build_dependencies: %{}
       }}
  """
  @spec parse_toml(path()) :: {:ok, manifest()} | {:error, String.t()}
  def parse_toml(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, do_parse(content)}
      {:error, reason} -> {:error, "Cannot read #{path}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Serialises a manifest map back to `Cargo.toml` format and writes it.

  ## Examples

      iex> Lux.Cargo.write_toml("/project/Cargo.toml", manifest)
      {:ok, :written}
  """
  @spec write_toml(path(), manifest()) :: {:ok, :written} | {:error, String.t()}
  def write_toml(path, manifest) do
    content = serialise(manifest)

    case File.write(path, content) do
      :ok -> {:ok, :written}
      {:error, reason} -> {:error, "Cannot write #{path}: #{:file.format_error(reason)}"}
    end
  end

  # ── Dependency management ───────────────────────────────────────────────────

  @doc """
  Adds or updates a crate dependency in `Cargo.toml`.

  If the crate is already listed, its version is replaced in-place.
  If the target `[section]` does not yet exist, it is appended.

  ## Options

    * `:section` — `:dependencies` (default), `:dev_dependencies`, or `:build_dependencies`
    * `:features` — list of feature strings, e.g. `["derive", "std"]`
    * `:optional` — mark the dependency optional (default: `false`)

  ## Examples

      iex> Lux.Cargo.add_dependency("Cargo.toml", "serde", "1.0", features: ["derive"])
      {:ok, :updated}

      iex> Lux.Cargo.add_dependency("Cargo.toml", "mockall", "0.13",
      ...>   section: :dev_dependencies)
      {:ok, :updated}
  """
  @spec add_dependency(path(), crate_name(), version_string(), keyword()) ::
          {:ok, :updated} | {:error, String.t()}
  def add_dependency(path, crate, version, opts \\ []) do
    section = Keyword.get(opts, :section, :dependencies)
    features = Keyword.get(opts, :features, [])
    optional = Keyword.get(opts, :optional, false)

    with {:ok, content} <- File.read(path) do
      dep_value = format_dep(version, features, optional)
      updated = upsert_dep(content, toml_section(section), crate, dep_value)

      case File.write(path, updated) do
        :ok -> {:ok, :updated}
        {:error, reason} -> {:error, "Write failed: #{:file.format_error(reason)}"}
      end
    else
      {:error, reason} -> {:error, "Cannot read #{path}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Removes a crate from the specified section of `Cargo.toml`.

  No-ops silently if the crate is not listed.

  ## Options

    * `:section` — `:dependencies` (default), `:dev_dependencies`, or `:build_dependencies`

  ## Examples

      iex> Lux.Cargo.remove_dependency("Cargo.toml", "serde")
      {:ok, :removed}
  """
  @spec remove_dependency(path(), crate_name(), keyword()) ::
          {:ok, :removed} | {:error, String.t()}
  def remove_dependency(path, crate, opts \\ []) do
    _section = Keyword.get(opts, :section, :dependencies)

    with {:ok, content} <- File.read(path) do
      updated = drop_dep(content, crate)

      case File.write(path, updated) do
        :ok -> {:ok, :removed}
        {:error, reason} -> {:error, "Write failed: #{:file.format_error(reason)}"}
      end
    else
      {:error, reason} -> {:error, "Cannot read #{path}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Returns all entries from the given dependency section.

  ## Examples

      iex> Lux.Cargo.list_dependencies("Cargo.toml")
      {:ok, %{"serde" => ~s("1.0"), "tokio" => ~s("1")}}

      iex> Lux.Cargo.list_dependencies("Cargo.toml", section: :dev_dependencies)
      {:ok, %{"mockall" => ~s("0.13")}}
  """
  @spec list_dependencies(path(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def list_dependencies(path, opts \\ []) do
    section = Keyword.get(opts, :section, :dependencies)

    with {:ok, manifest} <- parse_toml(path) do
      {:ok, Map.get(manifest, section, %{})}
    end
  end

  # ── Build system ────────────────────────────────────────────────────────────

  @doc """
  Runs `cargo build` in `project_dir`.

  ## Options

    * `:release` — compile with optimisations (default: `false`)
    * `:target` — target triple, e.g. `"aarch64-unknown-linux-musl"`
    * `:features` — list of features to activate

  ## Examples

      iex> Lux.Cargo.build("/project")
      {:ok, "    Finished dev [unoptimized + debuginfo] target(s) in 0.10s"}

      iex> Lux.Cargo.build("/project", release: true)
      {:ok, "    Finished release [optimized] target(s) in 2.34s"}
  """
  @spec build(path(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def build(project_dir, opts \\ []) do
    run_cargo(project_dir, ["build"] ++ build_flags(opts))
  end

  @doc """
  Runs `cargo test` in `project_dir`.

  ## Options

    * `:test_name` — filter to a specific test name
    * `:features` — list of features to activate

  ## Examples

      iex> Lux.Cargo.test("/project")
      {:ok, "test result: ok. 5 passed; 0 failed"}
  """
  @spec test(path(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def test(project_dir, opts \\ []) do
    base = ["test"] ++ feature_flags(opts)
    args = if name = Keyword.get(opts, :test_name), do: base ++ [name], else: base
    run_cargo(project_dir, args)
  end

  @doc """
  Runs `cargo check` for fast type-checking without producing a binary.

  ## Examples

      iex> Lux.Cargo.check("/project")
      {:ok, "    Finished checking [unoptimized + debuginfo]"}
  """
  @spec check(path(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def check(project_dir, opts \\ []) do
    run_cargo(project_dir, ["check"] ++ feature_flags(opts))
  end

  @doc """
  Runs `cargo fetch` to resolve and download all dependencies.

  ## Examples

      iex> Lux.Cargo.fetch("/project")
      {:ok, ""}
  """
  @spec fetch(path()) :: {:ok, String.t()} | {:error, String.t()}
  def fetch(project_dir) do
    run_cargo(project_dir, ["fetch"])
  end

  # ── Version management ──────────────────────────────────────────────────────

  @doc """
  Returns the newest stable version of `crate` according to crates.io.

  Results are cached in ETS for `#{@default_cache_ttl}` seconds (configurable
  via `config :lux, Lux.Cargo, cache_ttl: seconds`).

  ## Examples

      iex> Lux.Cargo.latest_version("serde")
      {:ok, "1.0.215"}
  """
  @spec latest_version(crate_name()) :: {:ok, version_string()} | {:error, String.t()}
  def latest_version(crate) do
    with {:ok, info} <- crate_info(crate) do
      case get_in(info, ["crate", "newest_version"]) do
        nil -> {:error, "No version field for #{crate}"}
        v -> {:ok, v}
      end
    end
  end

  @doc """
  Returns full crate metadata from crates.io.

  The response body is returned as-is (a map decoded from JSON).
  Responses are cached to avoid hitting crates.io rate limits.

  ## Examples

      iex> {:ok, info} = Lux.Cargo.crate_info("serde")
      iex> get_in(info, ["crate", "name"])
      "serde"
  """
  @spec crate_info(crate_name(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def crate_info(crate, req_opts \\ []) do
    ensure_table()
    key = {:crate_info, crate}

    case get_cached(key) do
      {:hit, data} ->
        {:ok, data}

      :miss ->
        case do_fetch_crate(crate, req_opts) do
          {:ok, data} ->
            put_cached(key, data)
            {:ok, data}

          error ->
            error
        end
    end
  end

  @doc """
  Returns `true` when the given `version` exists on crates.io.

  ## Examples

      iex> Lux.Cargo.version_exists?("serde", "1.0.0")
      true

      iex> Lux.Cargo.version_exists?("serde", "99.99.99")
      false
  """
  @spec version_exists?(crate_name(), version_string()) :: boolean()
  def version_exists?(crate, version, req_opts \\ []) do
    case crate_info(crate, req_opts) do
      {:ok, %{"versions" => versions}} -> Enum.any?(versions, &(&1["num"] == version))
      _ -> false
    end
  end

  # ── Private: TOML ───────────────────────────────────────────────────────────

  defp do_parse(content) do
    {_sec, sections} =
      content
      |> String.split("\n")
      |> Enum.reduce({nil, %{}}, fn line, {sec, acc} ->
        stripped = String.trim(line)

        cond do
          # Skip comments and blank lines
          stripped == "" or String.starts_with?(stripped, "#") ->
            {sec, acc}

          # Section header
          Regex.match?(~r/^\[([^\[\]]+)\]$/, stripped) ->
            [_, name] = Regex.run(~r/^\[([^\[\]]+)\]$/, stripped)
            {normalise_section(name), acc}

          # key = value inside a section
          sec != nil and Regex.match?(~r/^[\w-]+\s*=/, stripped) ->
            {k, v} = split_kv(stripped)
            {sec, Map.update(acc, sec, %{k => v}, &Map.put(&1, k, v))}

          true ->
            {sec, acc}
        end
      end)

    %{
      package: Map.get(sections, "package", %{}),
      dependencies: Map.get(sections, "dependencies", %{}),
      dev_dependencies: Map.get(sections, "dev-dependencies", %{}),
      build_dependencies: Map.get(sections, "build-dependencies", %{})
    }
  end

  defp normalise_section(name), do: String.replace(name, " ", "")

  defp split_kv(line) do
    [k | rest] = String.split(line, "=", parts: 2)
    {String.trim(k), String.trim(Enum.join(rest, "="))}
  end

  defp serialise(manifest) do
    sections = [
      {"package", manifest[:package] || %{}},
      {"dependencies", manifest[:dependencies] || %{}},
      {"dev-dependencies", manifest[:dev_dependencies] || %{}},
      {"build-dependencies", manifest[:build_dependencies] || %{}}
    ]

    sections
    |> Enum.reject(fn {_, v} -> map_size(v) == 0 end)
    |> Enum.map_join("\n\n", fn {name, entries} ->
      lines = Enum.map_join(entries, "\n", fn {k, v} -> "#{k} = #{v}" end)
      "[#{name}]\n#{lines}"
    end)
  end

  # ── Private: Dependency manipulation ───────────────────────────────────────

  defp toml_section(:dev_dependencies), do: "dev-dependencies"
  defp toml_section(:build_dependencies), do: "build-dependencies"
  defp toml_section(_), do: "dependencies"

  defp format_dep(version, [], false), do: ~s("#{version}")

  defp format_dep(version, features, optional) do
    parts = [~s(version = "#{version}")]
    parts = if features != [], do: parts ++ [~s(features = #{inspect(features)})], else: parts
    parts = if optional, do: parts ++ ["optional = true"], else: parts
    "{ #{Enum.join(parts, ", ")} }"
  end

  defp upsert_dep(content, section, crate, dep_value) do
    dep_line = "#{crate} = #{dep_value}"
    section_header = "[#{section}]"
    dep_re = ~r/^#{Regex.escape(crate)}\s*=.*/m

    cond do
      # Crate already listed — replace in-place regardless of section
      Regex.match?(dep_re, content) ->
        Regex.replace(dep_re, content, dep_line, global: false)

      # Section exists — insert right after the header
      String.contains?(content, section_header) ->
        String.replace(
          content,
          section_header <> "\n",
          section_header <> "\n" <> dep_line <> "\n",
          global: false
        )

      # Section missing — append it
      true ->
        String.trim_trailing(content) <> "\n\n[#{section}]\n#{dep_line}\n"
    end
  end

  defp drop_dep(content, crate) do
    dep_re = ~r/^#{Regex.escape(crate)}\s*=.*\n?/m

    content
    |> then(&Regex.replace(dep_re, &1, "", global: false))
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  # ── Private: Cargo runner ───────────────────────────────────────────────────

  defp run_cargo(dir, args) do
    case System.cmd("cargo", args, cd: dir, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, code} ->
        {:error, "cargo #{hd(args)} failed (exit #{code}):\n#{output}"}
    end
  rescue
    ErlangError ->
      {:error, "cargo not found — install Rust via https://rustup.rs"}
  end

  defp build_flags(opts) do
    flags = feature_flags(opts)
    flags = if Keyword.get(opts, :release, false), do: flags ++ ["--release"], else: flags
    if t = Keyword.get(opts, :target), do: flags ++ ["--target", t], else: flags
  end

  defp feature_flags(opts) do
    case Keyword.get(opts, :features, []) do
      [] -> []
      fs -> ["--features", Enum.join(fs, ",")]
    end
  end

  # ── Private: crates.io ──────────────────────────────────────────────────────

  defp do_fetch_crate(crate, req_opts) do
    app_env = Application.get_env(:lux, __MODULE__, [])
    base = Keyword.get(app_env, :crates_io_base, @crates_io_base)
    url = "#{base}/crates/#{crate}"

    opts =
      [headers: [{"User-Agent", @user_agent}]]
      |> Keyword.merge(Keyword.drop(app_env, [:cache_ttl, :crates_io_base]))
      |> Keyword.merge(req_opts)

    case Req.get(url, opts) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, "Crate '#{crate}' not found on crates.io"}

      {:ok, %{status: status}} ->
        {:error, "crates.io returned HTTP #{status} for '#{crate}'"}

      {:error, reason} ->
        {:error, "crates.io request failed: #{inspect(reason)}"}
    end
  end

  # ── Private: ETS cache ──────────────────────────────────────────────────────

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> @table
    end
  end

  defp cache_ttl do
    Application.get_env(:lux, __MODULE__, []) |> Keyword.get(:cache_ttl, @default_cache_ttl)
  end

  defp get_cached(key) do
    case :ets.lookup(@table, key) do
      [{^key, {data, ts}}] ->
        if System.monotonic_time(:second) - ts < cache_ttl() do
          {:hit, data}
        else
          :ets.delete(@table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp put_cached(key, data) do
    :ets.insert(@table, {key, {data, System.monotonic_time(:second)}})
    :ok
  end
end
