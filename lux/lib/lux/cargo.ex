defmodule Lux.Cargo do
  @moduledoc """
  Provides Cargo package management integration for Rust in Lux.

  Enables seamless dependency management, build system integration,
  version management, and package caching for Rust projects.

  The `~RUST` sigil is used to write Rust code directly in Elixir files.
  The Rust code must include a `fn main()` entry point, and output is captured
  from stdout.

  ## Features

  - **Cargo.toml Management** - Generate, parse, and modify Cargo.toml files
  - **Dependency Resolution** - Add, remove, and update Rust dependencies
  - **Build System Integration** - Compile Rust code and run builds from Elixir
  - **Version Management** - Check and manage dependency versions
  - **Package Caching** - Cache compiled artifacts for faster rebuilds
  - **Rust Code Evaluation** - Compile and run Rust snippets with `eval/2` or the `rust` macro

  ## Examples

      # Initialize a new Cargo project
      {:ok, project_path} = Lux.Cargo.init("my_rust_lib")

      # Add a dependency
      :ok = Lux.Cargo.add_dependency(project_path, "serde", "1.0")

      # Build the project
      {:ok, _output} = Lux.Cargo.build(project_path)

      # Evaluate Rust code inline
      {:ok, result} = Lux.Cargo.eval("fn main() { println!(\\"hello\\"); }")

      # Use the ~RUST sigil for multi-line Rust code
      require Lux.Cargo
      import Lux.Cargo

      result = rust do
        ~RUST\"\"\"
        fn main() {
            let sum: i32 = (1..=10).sum();
            println!("{}", sum);
        }
        \"\"\"
      end
      # => {:ok, "55"}
  """

  @type cargo_toml :: %{
          name: String.t(),
          version: String.t(),
          edition: String.t(),
          dependencies: map()
        }

  @type dependency :: %{
          name: String.t(),
          version: String.t(),
          features: [String.t()] | nil,
          optional: boolean() | nil
        }

  @type build_option ::
          {:release, boolean()}
          | {:target, String.t()}
          | {:features, [String.t()]}

  @type build_options :: [build_option()]

  @cache_dir Path.join(System.tmp_dir!(), "lux_cargo_cache")

  # -------------------------------------------------------------------
  # Cargo.toml Management
  # -------------------------------------------------------------------

  @doc """
  Initializes a new Cargo project at the given path.

  Creates a minimal Cargo.toml and src/lib.rs (or src/main.rs for binaries).

  ## Options

    * `:type` - `:lib` (default) or `:bin`
    * `:edition` - Rust edition, defaults to `"2021"`

  ## Examples

      iex> Lux.Cargo.init("/tmp/my_project")
      {:ok, "/tmp/my_project"}

      iex> Lux.Cargo.init("/tmp/my_bin", type: :bin)
      {:ok, "/tmp/my_bin"}
  """
  @spec init(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def init(path, opts \\ []) do
    type = Keyword.get(opts, :type, :lib)
    edition = Keyword.get(opts, :edition, "2021")
    name = Path.basename(path)

    with :ok <- File.mkdir_p(Path.join(path, "src")) do
      cargo_toml = generate_cargo_toml(name, "0.1.0", edition, %{})
      File.write!(Path.join(path, "Cargo.toml"), cargo_toml)

      src_file =
        case type do
          :bin -> Path.join([path, "src", "main.rs"])
          :lib -> Path.join([path, "src", "lib.rs"])
        end

      default_content =
        case type do
          :bin -> "fn main() {\n    println!(\"Hello from Lux!\");\n}\n"
          :lib -> "pub fn add(a: i32, b: i32) -> i32 {\n    a + b\n}\n\n#[cfg(test)]\nmod tests {\n    use super::*;\n\n    #[test]\n    fn test_add() {\n        assert_eq!(add(2, 3), 5);\n    }\n}\n"
        end

      File.write!(src_file, default_content)
      {:ok, path}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Parses a Cargo.toml file and returns its contents as a map.

  ## Examples

      iex> Lux.Cargo.parse_cargo_toml("/path/to/project")
      {:ok, %{name: "my_project", version: "0.1.0", edition: "2021", dependencies: %{}}}
  """
  @spec parse_cargo_toml(String.t()) :: {:ok, cargo_toml()} | {:error, String.t()}
  def parse_cargo_toml(project_path) do
    toml_path = Path.join(project_path, "Cargo.toml")

    case File.read(toml_path) do
      {:ok, content} ->
        {:ok, do_parse_cargo_toml(content)}

      {:error, reason} ->
        {:error, "Failed to read Cargo.toml: #{inspect(reason)}"}
    end
  end

  @doc """
  Generates a Cargo.toml string from the given parameters.

  ## Examples

      iex> Lux.Cargo.generate_cargo_toml("my_lib", "0.1.0", "2021", %{"serde" => "1.0"})
      "[package]\\nname = \\"my_lib\\"\\n..."
  """
  @spec generate_cargo_toml(String.t(), String.t(), String.t(), map()) :: String.t()
  def generate_cargo_toml(name, version, edition, dependencies) do
    deps_section =
      dependencies
      |> Enum.map_join("\n", fn
        {dep_name, version} when is_binary(version) ->
          "#{dep_name} = \"#{version}\""

        {dep_name, opts} when is_map(opts) ->
          features = Map.get(opts, :features, [])
          ver = Map.get(opts, :version, "*")

          if features == [] do
            "#{dep_name} = \"#{ver}\""
          else
            features_str = Enum.map_join(features, ", ", &"\"#{&1}\"")
            "#{dep_name} = { version = \"#{ver}\", features = [#{features_str}] }"
          end
      end)

    """
    [package]
    name = "#{name}"
    version = "#{version}"
    edition = "#{edition}"

    [dependencies]
    #{deps_section}
    """
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  # -------------------------------------------------------------------
  # Dependency Resolution
  # -------------------------------------------------------------------

  @doc """
  Adds a dependency to the project's Cargo.toml.

  ## Options

    * `:features` - List of features to enable
    * `:optional` - Whether the dependency is optional

  ## Examples

      iex> Lux.Cargo.add_dependency("/path/to/project", "serde", "1.0")
      :ok

      iex> Lux.Cargo.add_dependency("/path/to/project", "tokio", "1.0", features: ["full"])
      :ok
  """
  @spec add_dependency(String.t(), String.t(), String.t(), keyword()) ::
          :ok | {:error, String.t()}
  def add_dependency(project_path, dep_name, version, opts \\ []) do
    features = Keyword.get(opts, :features, [])

    case cargo_cmd(["add", dep_name <> "@" <> version] ++ features_args(features), project_path) do
      {:ok, _output} -> :ok
      {:error, _} = err -> err
    end
  end

  @doc """
  Removes a dependency from the project's Cargo.toml.

  ## Examples

      iex> Lux.Cargo.remove_dependency("/path/to/project", "serde")
      :ok
  """
  @spec remove_dependency(String.t(), String.t()) :: :ok | {:error, String.t()}
  def remove_dependency(project_path, dep_name) do
    case cargo_cmd(["remove", dep_name], project_path) do
      {:ok, _output} -> :ok
      {:error, _} = err -> err
    end
  end

  @doc """
  Updates dependencies in the project. If no dependency name is given,
  updates all dependencies.

  ## Examples

      iex> Lux.Cargo.update_dependencies("/path/to/project")
      {:ok, "Updated dependencies"}

      iex> Lux.Cargo.update_dependencies("/path/to/project", "serde")
      {:ok, "Updated serde"}
  """
  @spec update_dependencies(String.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def update_dependencies(project_path, dep_name \\ nil) do
    args = if dep_name, do: ["update", dep_name], else: ["update"]
    cargo_cmd(args, project_path)
  end

  @doc """
  Lists all dependencies and their resolved versions from Cargo.lock.

  ## Examples

      iex> Lux.Cargo.list_dependencies("/path/to/project")
      {:ok, %{"serde" => "1.0.193", "tokio" => "1.35.0"}}
  """
  @spec list_dependencies(String.t()) :: {:ok, map()} | {:error, String.t()}
  def list_dependencies(project_path) do
    lock_path = Path.join(project_path, "Cargo.lock")

    case File.read(lock_path) do
      {:ok, content} ->
        deps =
          content
          |> String.split("[[package]]")
          |> Enum.drop(1)
          |> Enum.reduce(%{}, fn block, acc ->
            name = extract_toml_value(block, "name")
            version = extract_toml_value(block, "version")

            if name && version do
              Map.put(acc, name, version)
            else
              acc
            end
          end)

        {:ok, deps}

      {:error, :enoent} ->
        # No Cargo.lock yet, run cargo generate-lockfile
        case cargo_cmd(["generate-lockfile"], project_path) do
          {:ok, _} -> list_dependencies(project_path)
          {:error, _} = err -> err
        end

      {:error, reason} ->
        {:error, "Failed to read Cargo.lock: #{inspect(reason)}"}
    end
  end

  # -------------------------------------------------------------------
  # Build System Integration
  # -------------------------------------------------------------------

  @doc """
  Builds a Cargo project.

  ## Options

    * `:release` - Build in release mode (default: false)
    * `:target` - Cross-compilation target
    * `:features` - List of features to enable

  ## Examples

      iex> Lux.Cargo.build("/path/to/project")
      {:ok, "Compiling my_project v0.1.0..."}

      iex> Lux.Cargo.build("/path/to/project", release: true)
      {:ok, "Compiling my_project v0.1.0 (release)..."}
  """
  @spec build(String.t(), build_options()) :: {:ok, String.t()} | {:error, String.t()}
  def build(project_path, opts \\ []) do
    args = ["build"] ++ build_args(opts)
    cargo_cmd(args, project_path)
  end

  @doc """
  Runs `cargo test` in the given project.

  ## Examples

      iex> Lux.Cargo.test("/path/to/project")
      {:ok, "test result: ok. 5 passed; 0 failed"}
  """
  @spec test(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def test(project_path, opts \\ []) do
    args = ["test"] ++ build_args(opts)
    cargo_cmd(args, project_path)
  end

  @doc """
  Runs `cargo check` for fast compilation checking without producing binaries.

  ## Examples

      iex> Lux.Cargo.check("/path/to/project")
      {:ok, "Checking my_project v0.1.0..."}
  """
  @spec check(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def check(project_path) do
    cargo_cmd(["check"], project_path)
  end

  @doc """
  Evaluates Rust code by creating a temporary Cargo project, compiling and running it.

  This is useful for quick one-off Rust evaluations from Elixir.

  ## Options

    * `:dependencies` - Map of dependencies to include
    * `:timeout` - Timeout in milliseconds (default: 60_000)

  ## Examples

      iex> Lux.Cargo.eval(~S'fn main() { println!("{}", 2 + 2); }')
      {:ok, "4"}

      iex> Lux.Cargo.eval(~S'fn main() { let v: Vec<i32> = (1..=5).collect(); println!("{:?}", v); }')
      {:ok, "[1, 2, 3, 4, 5]"}
  """
  @spec eval(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    dependencies = Keyword.get(opts, :dependencies, %{})
    timeout = Keyword.get(opts, :timeout, 60_000)

    # Create a temporary project
    tmp_dir = Path.join(System.tmp_dir!(), "lux_cargo_eval_#{:erlang.unique_integer([:positive])}")

    try do
      with {:ok, _} <- init(tmp_dir, type: :bin),
           :ok <- File.write(Path.join([tmp_dir, "src", "main.rs"]), code) do
        # Add dependencies if specified
        if map_size(dependencies) > 0 do
          cargo_toml = generate_cargo_toml("lux_eval", "0.1.0", "2021", dependencies)
          File.write!(Path.join(tmp_dir, "Cargo.toml"), cargo_toml)
        end

        case cargo_cmd(["run"], tmp_dir, timeout) do
          {:ok, output} -> {:ok, String.trim(output)}
          {:error, _} = err -> err
        end
      end
    after
      File.rm_rf(tmp_dir)
    end
  end

  # -------------------------------------------------------------------
  # Version Management
  # -------------------------------------------------------------------

  @doc """
  Checks the installed version of the Cargo/Rust toolchain.

  ## Examples

      iex> Lux.Cargo.toolchain_version()
      {:ok, %{cargo: "1.74.0", rustc: "1.74.0"}}
  """
  @spec toolchain_version() :: {:ok, map()} | {:error, String.t()}
  def toolchain_version do
    with {:ok, cargo_v} <- cmd("cargo", ["--version"]),
         {:ok, rustc_v} <- cmd("rustc", ["--version"]) do
      cargo_version =
        cargo_v |> String.trim() |> String.split(" ") |> Enum.at(1, "unknown")

      rustc_version =
        rustc_v |> String.trim() |> String.split(" ") |> Enum.at(1, "unknown")

      {:ok, %{cargo: cargo_version, rustc: rustc_version}}
    end
  end

  @doc """
  Checks if a specific crate version exists on crates.io.

  ## Examples

      iex> Lux.Cargo.check_crate_version("serde", "1.0.193")
      {:ok, true}

      iex> Lux.Cargo.check_crate_version("nonexistent_crate_xyz", "0.0.1")
      {:ok, false}
  """
  @spec check_crate_version(String.t(), String.t()) :: {:ok, boolean()} | {:error, String.t()}
  def check_crate_version(crate_name, version) do
    case cargo_cmd(["search", crate_name, "--limit", "1"], System.tmp_dir!()) do
      {:ok, output} ->
        {:ok, String.contains?(output, crate_name) && check_version_match(output, version)}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Gets information about a crate from crates.io via `cargo search`.

  ## Examples

      iex> Lux.Cargo.search_crate("serde")
      {:ok, [%{name: "serde", version: "1.0.193", description: "..."}]}
  """
  @spec search_crate(String.t(), keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def search_crate(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    case cargo_cmd(["search", query, "--limit", to_string(limit)], System.tmp_dir!()) do
      {:ok, output} ->
        crates =
          output
          |> String.split("\n")
          |> Enum.filter(&String.contains?(&1, "="))
          |> Enum.map(fn line ->
            case Regex.run(~r/^(\S+)\s*=\s*"([^"]+)"(.*)$/, line) do
              [_, name, version, rest] ->
                description = rest |> String.trim() |> String.trim_leading("#") |> String.trim()
                %{name: name, version: version, description: description}

              _ ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, crates}

      {:error, _} = err ->
        err
    end
  end

  # -------------------------------------------------------------------
  # Package Caching
  # -------------------------------------------------------------------

  @doc """
  Returns the path to the Cargo cache directory used by Lux.

  ## Examples

      iex> Lux.Cargo.cache_dir()
      "/tmp/lux_cargo_cache"
  """
  @spec cache_dir() :: String.t()
  def cache_dir, do: @cache_dir

  @doc """
  Ensures the package cache directory exists and returns its path.

  ## Examples

      iex> Lux.Cargo.ensure_cache()
      {:ok, "/tmp/lux_cargo_cache"}
  """
  @spec ensure_cache() :: {:ok, String.t()} | {:error, String.t()}
  def ensure_cache do
    case File.mkdir_p(@cache_dir) do
      :ok -> {:ok, @cache_dir}
      {:error, reason} -> {:error, "Failed to create cache directory: #{inspect(reason)}"}
    end
  end

  @doc """
  Clears the Lux Cargo cache.

  ## Examples

      iex> Lux.Cargo.clear_cache()
      :ok
  """
  @spec clear_cache() :: :ok | {:error, String.t()}
  def clear_cache do
    case File.rm_rf(@cache_dir) do
      {:ok, _} -> :ok
      {:error, reason, _} -> {:error, "Failed to clear cache: #{inspect(reason)}"}
    end
  end

  @doc """
  Returns the size of the cache directory in bytes.

  ## Examples

      iex> Lux.Cargo.cache_size()
      {:ok, 1048576}
  """
  @spec cache_size() :: {:ok, non_neg_integer()} | {:error, String.t()}
  def cache_size do
    if File.dir?(@cache_dir) do
      size =
        @cache_dir
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.reduce(0, fn path, acc ->
          case File.stat(path) do
            {:ok, %{size: size}} -> acc + size
            _ -> acc
          end
        end)

      {:ok, size}
    else
      {:ok, 0}
    end
  end

  @doc """
  Configures the CARGO_HOME environment variable for caching.
  Sets up a shared registry cache to avoid re-downloading crate metadata.

  ## Examples

      iex> Lux.Cargo.setup_cache_env()
      %{"CARGO_HOME" => "/tmp/lux_cargo_cache/cargo_home"}
  """
  @spec setup_cache_env() :: map()
  def setup_cache_env do
    cargo_home = Path.join(@cache_dir, "cargo_home")
    File.mkdir_p!(cargo_home)
    %{"CARGO_HOME" => cargo_home}
  end

  # -------------------------------------------------------------------
  # Rust Code Evaluation Macro & Sigil
  # -------------------------------------------------------------------

  @doc """
  A macro for executing Rust code with optional dependencies.
  Rust code should be wrapped in the `~RUST` sigil.

  The Rust code must contain a `fn main()` entry point. Output is captured
  from stdout.

  ## Options

    * `:dependencies` - Map of crate dependencies to include (e.g., `%{"serde" => "1.0"}`)
    * `:timeout` - Timeout in milliseconds (default: 60_000)

  ## Examples

      require Lux.Cargo
      import Lux.Cargo

      result = rust do
        ~RUST\"\"\"
        fn main() {
            println!("{}", 2 + 2);
        }
        \"\"\"
      end
      # => {:ok, "4"}

      result = rust dependencies: %{"rand" => "0.8"} do
        ~RUST\"\"\"
        use rand::Rng;
        fn main() {
            let mut rng = rand::thread_rng();
            let n: u32 = rng.gen_range(1..=100);
            println!("{}", n);
        }
        \"\"\"
      end
  """
  defmacro rust(opts \\ [], do: {:sigil_RUST, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      Lux.Cargo.eval(unquote(code), unquote(opts))
    end
  end

  @doc false
  defmacro sigil_RUST({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end

  # -------------------------------------------------------------------
  # Private Helpers
  # -------------------------------------------------------------------

  defp cargo_cmd(args, cwd, timeout \\ 120_000) do
    env = setup_cache_env()
    env_list = Enum.map(env, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    try do
      case System.cmd("cargo", args,
             cd: cwd,
             stderr_to_stdout: true,
             env: env_list,
             timeout: timeout
           ) do
        {output, 0} -> {:ok, output}
        {output, code} -> {:error, "Cargo command failed (exit #{code}): #{output}"}
      end
    rescue
      e in ErlangError ->
        case e do
          %ErlangError{original: :enoent} ->
            {:error, "Cargo not found. Please install Rust: https://rustup.rs"}

          _ ->
            {:error, "Cargo command error: #{Exception.message(e)}"}
        end
    end
  end

  defp cmd(command, args) do
    try do
      case System.cmd(command, args, stderr_to_stdout: true) do
        {output, 0} -> {:ok, output}
        {output, code} -> {:error, "Command '#{command}' failed (exit #{code}): #{output}"}
      end
    rescue
      e in ErlangError ->
        {:error, "#{command} not found: #{Exception.message(e)}"}
    end
  end

  defp build_args(opts) do
    args = []
    args = if Keyword.get(opts, :release, false), do: args ++ ["--release"], else: args

    args =
      case Keyword.get(opts, :target) do
        nil -> args
        target -> args ++ ["--target", target]
      end

    case Keyword.get(opts, :features) do
      nil -> args
      [] -> args
      features -> args ++ ["--features", Enum.join(features, ",")]
    end
  end

  defp features_args([]), do: []
  defp features_args(features), do: ["--features", Enum.join(features, ",")]

  defp do_parse_cargo_toml(content) do
    name = extract_toml_value(content, "name") || ""
    version = extract_toml_value(content, "version") || "0.1.0"
    edition = extract_toml_value(content, "edition") || "2021"

    # Parse dependencies section
    deps =
      case Regex.run(~r/\[dependencies\]\n(.*?)(\n\[|\z)/s, content) do
        [_, deps_section | _] ->
          deps_section
          |> String.split("\n")
          |> Enum.reject(&(String.trim(&1) == ""))
          |> Enum.reduce(%{}, fn line, acc ->
            case Regex.run(~r/^(\S+)\s*=\s*"([^"]+)"/, line) do
              [_, dep_name, dep_version] -> Map.put(acc, dep_name, dep_version)
              _ -> acc
            end
          end)

        _ ->
          %{}
      end

    %{name: name, version: version, edition: edition, dependencies: deps}
  end

  defp extract_toml_value(content, key) do
    case Regex.run(~r/#{Regex.escape(key)}\s*=\s*"([^"]+)"/, content) do
      [_, value] -> value
      _ -> nil
    end
  end

  defp check_version_match(output, version) do
    String.contains?(output, "\"#{version}\"") ||
      String.contains?(output, version)
  end
end
