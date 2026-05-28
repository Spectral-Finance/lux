defmodule Lux.Rust do
  @moduledoc """
  Top-level module for executing Rust code from Elixir.

  Provides inline Rust evaluation by creating a temporary Cargo project,
  writing `src/main.rs`, and invoking `cargo run`. Dependency injection,
  compilation-only mode, and runtime availability checks are also provided.

  ## Examples

      iex> Lux.Rust.available?()
      true

      iex> {:ok, version} = Lux.Rust.version()
      iex> String.starts_with?(version, "rustc")
      true

      iex> Lux.Rust.eval(~s[fn main() { println!("hello"); }])
      {:ok, "hello\\n"}

      iex> Lux.Rust.with_deps(
      ...>   ~s[fn main() { println!("{}", serde_json::json!({"ok": true})); }],
      ...>   [{"serde_json", "1"}],
      ...>   []
      ...> )
      {:ok, _output}
  """

  @type eval_option ::
          {:timeout, pos_integer()}
          | {:edition, String.t()}

  @type eval_options :: [eval_option()]

  @default_edition "2021"
  @default_timeout 30_000

  @doc """
  Returns `true` when both `rustc` and `cargo` are available in the system PATH.

  ## Examples

      iex> Lux.Rust.available?()
      true
  """
  @spec available?() :: boolean()
  def available? do
    has_executable?("rustc") and has_executable?("cargo")
  end

  @doc """
  Returns the installed Rust compiler version string.

  ## Examples

      iex> {:ok, version} = Lux.Rust.version()
      iex> String.starts_with?(version, "rustc")
      true
  """
  @spec version() :: {:ok, String.t()} | {:error, String.t()}
  def version do
    case System.cmd("rustc", ["--version"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Compiles and runs `code` as a standalone Rust `main.rs` inside a temporary
  Cargo project.

  Returns `{:ok, stdout}` on success or `{:error, stderr}` on compilation or
  runtime failure.

  ## Options

    * `:timeout` - milliseconds to wait for `cargo run` (default: #{@default_timeout})
    * `:edition` - Rust edition to use in `Cargo.toml` (default: `"#{@default_edition}"`)

  ## Examples

      iex> Lux.Rust.eval(~s[fn main() { println!("hello"); }])
      {:ok, "hello\\n"}

      iex> Lux.Rust.eval(~s[fn main() { let _: i32 = "bad"; }])
      {:error, _stderr}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, String.t()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    with_deps(code, [], opts)
  end

  @doc """
  Compiles `code` inside a temporary Cargo project but does not execute the
  resulting binary.

  Returns `{:ok, binary_path}` where `binary_path` is the path to the compiled
  executable, or `{:error, reason}` on failure.  The caller is responsible for
  cleaning up the temporary directory.

  ## Options

    * `:timeout` - milliseconds to wait for `cargo build` (default: #{@default_timeout})
    * `:edition` - Rust edition string (default: `"#{@default_edition}"`)

  ## Examples

      iex> Lux.Rust.compile(~s[fn main() {}])
      {:ok, binary_path}
  """
  @spec compile(String.t(), eval_options()) :: {:ok, String.t()} | {:error, String.t()}
  def compile(code, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    edition = Keyword.get(opts, :edition, @default_edition)

    dir = make_temp_dir()

    try do
      write_cargo_project(dir, code, [], edition)

      case System.cmd("cargo", ["build", "--release"],
             cd: dir,
             stderr_to_stdout: true,
             timeout: timeout
           ) do
        {_output, 0} ->
          binary = find_compiled_binary(dir)
          {:ok, binary}

        {output, _} ->
          {:error, String.trim(output)}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @doc """
  Evaluates `code` with additional Cargo dependencies declared via `deps`.

  Each entry in `deps` is a `{crate_name, version_req}` tuple.

  ## Examples

      iex> Lux.Rust.with_deps(
      ...>   ~s[fn main() { println!("{}", serde_json::json!(42)); }],
      ...>   [{"serde_json", "1"}],
      ...>   []
      ...> )
      {:ok, "42\\n"}
  """
  @spec with_deps(String.t(), [{String.t(), String.t()}], eval_options()) ::
          {:ok, String.t()} | {:error, String.t()}
  def with_deps(code, deps, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    edition = Keyword.get(opts, :edition, @default_edition)

    dir = make_temp_dir()

    try do
      write_cargo_project(dir, code, deps, edition)

      case System.cmd("cargo", ["run", "--release"],
             cd: dir,
             stderr_to_stdout: false,
             timeout: timeout
           ) do
        {stdout, 0} -> {:ok, stdout}
        {_stdout, _code} -> collect_stderr(dir, timeout)
      end
    rescue
      e -> {:error, Exception.message(e)}
    after
      File.rm_rf(dir)
    end
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp make_temp_dir do
    base = System.tmp_dir!()
    unique = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    dir = Path.join(base, "lux_rust_#{unique}")
    File.mkdir_p!(dir)
    File.mkdir_p!(Path.join(dir, "src"))
    dir
  end

  defp write_cargo_project(dir, code, deps, edition) do
    File.write!(Path.join([dir, "src", "main.rs"]), code)
    File.write!(Path.join(dir, "Cargo.toml"), build_cargo_toml(deps, edition))
  end

  defp build_cargo_toml(deps, edition) do
    dep_lines =
      Enum.map_join(deps, "\n", fn {name, version} ->
        ~s[#{name} = "#{version}"]
      end)

    """
    [package]
    name = "lux_eval"
    version = "0.1.0"
    edition = "#{edition}"

    [dependencies]
    #{dep_lines}
    """
  end

  defp find_compiled_binary(dir) do
    target_dir = Path.join([dir, "target", "release"])

    case File.ls(target_dir) do
      {:ok, entries} ->
        entries
        |> Enum.reject(&String.starts_with?(&1, "."))
        |> Enum.find(fn name ->
          path = Path.join(target_dir, name)
          File.regular?(path) and executable?(path)
        end)
        |> case do
          nil -> Path.join(target_dir, "lux_eval")
          name -> Path.join(target_dir, name)
        end

      {:error, _} ->
        Path.join([dir, "target", "release", "lux_eval"])
    end
  end

  defp collect_stderr(dir, timeout) do
    case System.cmd("cargo", ["build", "--release"],
           cd: dir,
           stderr_to_stdout: true,
           timeout: timeout
         ) do
      {output, _} -> {:error, String.trim(output)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp has_executable?(name) do
    case System.find_executable(name) do
      nil -> false
      _ -> true
    end
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %{type: :regular}} ->
        mode_bits = path |> File.stat!() |> Map.get(:mode)
        (mode_bits &&& 0o111) != 0

      _ ->
        false
    end
  rescue
    _ -> false
  end
end
