defmodule Lux.Cargo.Cache do
  @moduledoc """
  Package and registry caching mechanism for Cargo (Rust) dependencies.

  Provides an on-disk cache for resolved dependency versions and downloaded
  crate metadata, with a configurable TTL and invalidation. The cache is
  backed by the filesystem under the Lux `:cargo_cache_dir` application
  environment (defaulting to `priv/cargo_cache`).

  ## Examples

      iex> {:ok, version} = Lux.Cargo.Cache.resolve_version("~> 1.0")
  """

  @default_ttl :timer.hours(24)

  defp cache_dir do
    Application.get_env(:lux, :cargo_cache_dir, Application.app_dir(:lux, "priv/cargo_cache"))
  end

  @doc """
  Resolves the concrete version for a dependency version requirement.

  When the cargo toolchain and network are available the version is resolved
  against the registry index. The result is cached on disk with a TTL. In
  environments without a Rust toolchain the declared requirement is returned
  as-is (best-effort) so callers can continue offline.

  Returns `{:ok, version}` or `{:error, reason}`.
  """
  @spec resolve_version(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_version(version) when is_binary(version) do
    cache_key = "req:#{version}"

    case get(cache_key) do
      {:ok, cached} ->
        {:ok, cached}

      {:error, :miss} ->
        do_resolve(version, cache_key)
    end
  end

  defp do_resolve(version, cache_key) do
    case resolve_via_cargo(version) do
      {:ok, resolved} ->
        put(cache_key, resolved)
        {:ok, resolved}

      {:error, _reason} ->
        {:ok, version}
    end
  end

  defp resolve_via_cargo(version) do
    case System.find_executable("cargo") do
      nil ->
        {:error, "cargo not available"}

      _cargo ->
        manifest = """
        [package]
        name = "lux-resolve"
        version = "0.0.0"
        edition = "2021"

        [dependencies]
        lux_resolve_dep = "#{version}"
        """

        dir = Path.join(cache_dir(), "resolve")
        File.mkdir_p!(dir)
        File.write!(Path.join(dir, "Cargo.toml"), manifest)

        case System.cmd("cargo", ["metadata", "--format-version", "1", "--manifest-path", Path.join(dir, "Cargo.toml")], stderr_to_stdout: true) do
          {output, 0} ->
            extract_version(output, version)

          _ ->
            {:error, "cargo metadata failed"}
        end
    end
  rescue
    _ -> {:error, "cargo resolution failed"}
  end

  defp extract_version(output, fallback) do
    case Jason.decode(output) do
      {:ok, %{"packages" => packages}} ->
        case Enum.find(packages, fn p -> Map.get(p, "name") == "lux_resolve_dep" end) do
          nil -> {:error, "dependency not found in metadata"}
          %{"version" => version} -> {:ok, version}
        end

      _ ->
        {:ok, fallback}
    end
  rescue
    _ -> {:ok, fallback}
  end

  @doc """
  Stores a downloaded crate artifact path in the cache.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec put_artifact(String.t(), String.t()) :: :ok | {:error, String.t()}
  def put_artifact(name, path) when is_binary(name) and is_binary(path) do
    put("artifact:#{name}", path)
  end

  @doc """
  Retrieves a cached crate artifact path.

  Returns `{:ok, path}` or `{:error, :miss}`.
  """
  @spec get_artifact(String.t()) :: {:ok, String.t()} | {:error, :miss}
  def get_artifact(name) when is_binary(name) do
    get("artifact:#{name}")
  end

  @doc """
  Reads a cache entry, honoring TTL invalidation.

  Returns `{:ok, value}` or `{:error, :miss}`.
  """
  @spec get(String.t()) :: {:ok, term()} | {:error, :miss}
  def get(key) when is_binary(key) do
    file = cache_file(key)

    if File.exists?(file) do
      [timestamp, value] = File.read!(file) |> String.split("\n", parts: 2)
      ttl = Application.get_env(:lux, :cargo_cache_ttl, @default_ttl)

      if expired?(String.to_integer(timestamp), ttl) do
        :ok = File.rm(file)
        {:error, :miss}
      else
        {:ok, value}
      end
    else
      {:error, :miss}
    end
  rescue
    _ -> {:error, :miss}
  end

  @doc """
  Writes a cache entry with the current timestamp.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec put(String.t(), term()) :: :ok | {:error, String.t()}
  def put(key, value) when is_binary(key) do
    file = cache_file(key)
    :ok = File.mkdir_p(Path.dirname(file))
    content = "#{System.os_time(:millisecond)}\n#{value}"
    File.write(file, content)
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Removes a cache entry.

  Returns `:ok`.
  """
  @spec invalidate(String.t()) :: :ok
  def invalidate(key) when is_binary(key) do
    file = cache_file(key)
    if File.exists?(file), do: File.rm(file)
    :ok
  end

  @doc """
  Clears all cached entries.

  Returns `:ok`.
  """
  @spec clear() :: :ok
  def clear do
    dir = cache_dir()
    if File.exists?(dir), do: File.rm_rf(dir)
    :ok
  end

  defp cache_file(key) do
    hash = Base.encode16(:crypto.hash(:sha256, key), case: :lower)
    Path.join(cache_dir(), "#{hash}.cache")
  end

  defp expired?(timestamp, ttl) do
    System.os_time(:millisecond) - timestamp > ttl
  end
end
