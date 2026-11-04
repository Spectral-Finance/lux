defmodule Lux.Cargo do
  @moduledoc """
  Provides functions for managing Rust/Cargo packages and executing Rust code in Lux.

  This module implements Cargo package management integration, enabling seamless
  dependency management and build system integration for Rust in Lux.

  ## Core Features

  * Cargo.toml management - generation, parsing, and modification
  * Dependency resolution - add, remove, and resolve crate dependencies
  * Build system integration - cargo build, check, test execution
  * Version management - Rust toolchain and crate version queries
  * Package caching - cargo registry cache management
  """

  @type eval_option :: {:variables, map()} | {:timeout, pos_integer()}
  @type eval_options :: [eval_option()]
  @type cargo_toml :: map()
  @type dependency_result :: %{
          name: String.t(),
          version: String.t() | nil,
          success: boolean(),
          error: String.t() | nil
        }

  @module_path Application.app_dir(:lux, "priv/cargo")

  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @spec eval(String.t(), eval_options()) :: {:ok, String.t()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 120)
    with {:ok, project_dir} <- create_temp_project(code),
         {:ok, _output} <- build_project(project_dir, timeout: timeout),
         {:ok, output} <- run_project(project_dir, timeout: timeout) do
      {:ok, output}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec eval!(String.t(), eval_options()) :: String.t() | no_return()
  def eval!(code, opts \\ []) do
    case eval(code, opts) do
      {:ok, result} -> result
      {:error, error} -> raise RuntimeError, "Cargo execution error: #{error}"
    end
  end

  @spec generate_cargo_toml(String.t(), [{String.t(), String.t()}]) ::
          {:ok, cargo_toml()} | {:error, String.t()}
  def generate_cargo_toml(project_name, dependencies \\ []) when is_binary(project_name) do
    if String.trim(project_name) == "" do
      {:error, "project_name must not be empty"}
    else
      cargo_toml = %{
        "package" => %{
          "name" => project_name,
          "version" => "0.1.0",
          "edition" => "2021"
        },
        "dependencies" => Enum.into(dependencies, %{}, fn {name, version} -> {name, version} end)
      }
      {:ok, cargo_toml}
    end
  end

  @spec parse_cargo_toml(String.t()) :: {:ok, cargo_toml()} | {:error, String.t()}
  def parse_cargo_toml(path) when is_binary(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> parse_toml_content(content)
        {:error, error} -> {:error, "Failed to read Cargo.toml: #{inspect(error)}"}
      end
    else
      {:error, "Cargo.toml not found at: #{path}"}
    end
  end

  @spec add_dependency(String.t(), String.t(), String.t() | nil) ::
          {:ok, dependency_result()} | {:error, String.t()}
  def add_dependency(path, dep_name, version \\ nil) when is_binary(path) and is_binary(dep_name) do
    version = version || "*"
    case parse_cargo_toml(path) do
      {:ok, cargo_toml} ->
        dependencies = Map.get(cargo_toml, "dependencies", %{})
        updated_deps = Map.put(dependencies, dep_name, version)
        updated_toml = Map.put(cargo_toml, "dependencies", updated_deps)
        case write_cargo_toml(path, updated_toml) do
          :ok ->
            {:ok, %{name: dep_name, version: version, success: true, error: nil}}
          {:error, error} -> {:error, error}
        end
      {:error, error} -> {:error, error}
    end
  end

  @spec remove_dependency(String.t(), String.t()) ::
          {:ok, dependency_result()} | {:error, String.t()}
  def remove_dependency(path, dep_name) when is_binary(path) and is_binary(dep_name) do
    case parse_cargo_toml(path) do
      {:ok, cargo_toml} ->
        dependencies = Map.get(cargo_toml, "dependencies", %{})
        if Map.has_key?(dependencies, dep_name) do
          updated_deps = Map.delete(dependencies, dep_name)
          updated_toml = Map.put(cargo_toml, "dependencies", updated_deps)
          write_and_return(path, updated_toml, dep_name, nil, true, nil)
        else
          {:error, "Dependency '#{dep_name}' not found in Cargo.toml"}
        end
      {:error, error} -> {:error, error}
    end
  end

  defp write_and_return(path, updated_toml, dep_name, version, success, error) do
    case write_cargo_toml(path, updated_toml) do
      :ok -> {:ok, %{name: dep_name, version: version, success: success, error: error}}
      {:error, error} -> {:error, error}
    end
  end

  @spec build(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def build(opts \\ []) do
    run_cargo_command(["build"], opts)
  end

  @spec check(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def check(opts \\ []) do
    run_cargo_command(["check"], opts)
  end

  @spec test(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def test(opts \\ []) do
    run_cargo_command(["test"], opts)
  end

  @spec rust_version() :: {:ok, String.t()} | {:error, String.t()}
  def rust_version do
    case safe_cmd("rustc", ["--version"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {:error, :not_found} -> {:error, "Rust toolchain not found. Please install Rust via rustup."}
      {output, _} -> {:error, "Failed to get Rust version: #{String.trim(output)}"}
    end
  end

  @spec crate_available(String.t()) ::
          {:ok, %{available: boolean(), version: String.t() | nil}} | {:error, String.t()}
  def crate_available(crate_name) when is_binary(crate_name) do
    if String.trim(crate_name) == "" do
      {:ok, %{available: false, version: nil}}
    else
      cache_dir = cache_dir()
      registry_dir = Path.join([cache_dir, "registry", "src"])
      check_crate_in_registry(registry_dir, crate_name)
    end
  end

  defp check_crate_in_registry(registry_dir, crate_name) do
    if File.exists?(registry_dir) do
      matches =
        Path.wildcard(Path.join([registry_dir, "*#{crate_name}*"]))
        |> Enum.filter(&File.dir?/1)
      check_crate_matches(matches)
    else
      {:ok, %{available: false, version: nil}}
    end
  end

  defp check_crate_matches([]), do: {:ok, %{available: false, version: nil}}
  defp check_crate_matches(matches) do
    version = matches |> List.first() |> Path.basename() |> extract_version()
    {:ok, %{available: true, version: version}}
  end

  @spec cache_dir() :: String.t()
  def cache_dir do
    case System.get_env("CARGO_HOME") do
      nil -> Path.join(System.user_home!(), ".cargo")
      dir -> dir
    end
  end

  @spec clear_cache() :: :ok | {:error, String.t()}
  def clear_cache do
    cache_dir = cache_dir()
    registry_dir = Path.join([cache_dir, "registry"])
    if File.exists?(registry_dir) do
      File.rm_rf!(registry_dir)
      :ok
    else
      :ok
    end
  end

  @spec fetch(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def fetch(opts \\ []) do
    run_cargo_command(["fetch"], opts)
  end

  # === Private implementation ===

  defp create_temp_project(code) do
    _tmp_dir = System.tmp_dir!()
    hash = :crypto.hash(:sha256, code) |> Base.encode16(case: :lower) |> String.slice(0..15)
    project_name = "lux_cargo_#{hash}"
    project_dir = Path.join(System.tmp_dir!(), project_name)
    src_dir = Path.join(project_dir, "src")
    if File.exists?(project_dir) do
      {:ok, project_dir}
    else
      with :ok <- File.mkdir_p(src_dir),
           :ok <- write_cargo_toml(Path.join(project_dir, "Cargo.toml"), generate_default_toml(project_name)),
           :ok <- write_file(Path.join(src_dir, "main.rs"), code) do
        {:ok, project_dir}
      else
        {:error, error} -> {:error, "Failed to create temp project: #{inspect(error)}"}
      end
    end
  end

  defp generate_default_toml(project_name) do
    %{"package" => %{"name" => project_name, "version" => "0.1.0", "edition" => "2021"}, "dependencies" => %{}}
  end

  defp run_cargo_command(args, opts) do
    path = Keyword.get(opts, :path, module_path())
    release = Keyword.get(opts, :release, false)
    timeout = Keyword.get(opts, :timeout, 300)
    full_args = args ++ (if release, do: ["--release"], else: [])
    case safe_cmd("cargo", full_args, cd: path, stderr_to_stdout: true, timeout: timeout * 1000) do
      {:error, :not_found} ->
        {:error, "Cargo not found. Please install Rust via rustup."}
      {output, 0} ->
        {:ok, String.trim(output)}
      {output, status} ->
        {:error, "cargo #{Enum.join(args, " ")} failed (status #{status}): #{String.trim(output)}"}
    end
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} ->
          {:error, "Cargo not found. Please install Rust via rustup."}
        _ ->
          {:error, "Unexpected error running cargo: #{Exception.message(e)}"}
      end
  end

  defp build_project(project_dir, opts) do
    run_cargo_command(["build"], opts ++ [path: project_dir])
  end

  defp run_project(project_dir, opts) do
    timeout = Keyword.get(opts, :timeout, 120)
    binary_name = Path.basename(project_dir)
    binary_path = Path.join([project_dir, "target", "debug", binary_name])
    case safe_cmd(binary_path, [], stderr_to_stdout: true, timeout: timeout * 1000) do
      {:error, :not_found} ->
        {:error, "Compiled binary not found at #{binary_path}"}
      {output, 0} ->
        {:ok, String.trim(output)}
      {output, status} ->
        {:error, "Binary execution failed (status #{status}): #{String.trim(output)}"}
    end
  end

  defp write_cargo_toml(path, toml_map) do
    content = serialize_toml(toml_map)
    write_file(path, content)
  end

  defp write_file(path, content) do
    case File.write(path, content) do
      :ok -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp parse_toml_content(content) do
    lines = String.split(content, "\n")
    {result, _current_section} =
      Enum.reduce(lines, {%{}, nil}, fn line, {result, current_section} ->
        parse_toml_line(line, result, current_section)
      end)
    {:ok, result}
  end

  defp parse_toml_line(line, result, current_section) do
    line = String.trim(line)
    cond do
      String.starts_with?(line, "#") or line == "" ->
        {result, current_section}
      String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
        section_name = String.trim(String.slice(line, 1..-2//1))
        {Map.put(result, section_name, %{}), section_name}
      true ->
        parse_key_value(line, result, current_section)
    end
  end

  defp parse_key_value(line, result, current_section) do
    case String.split(line, "=") do
      [key, value] ->
        key = String.trim(key)
        value = parse_toml_value(String.trim(value))
        if current_section do
          section_map = Map.get(result, current_section, %{})
          updated_section = Map.put(section_map, key, value)
          {Map.put(result, current_section, updated_section), current_section}
        else
          {Map.put(result, key, value), current_section}
        end
      _ ->
        {result, current_section}
    end
  end

  defp parse_toml_value(value) do
    cond do
      String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
        String.slice(value, 1..-2//1)
      String.starts_with?(value, "[") and String.ends_with?(value, "]") ->
        parse_toml_array(value)
      true ->
        parse_toml_scalar(value)
    end
  end

  defp parse_toml_array(value) do
    inner = String.slice(value, 1..-2//1) |> String.trim()
    if inner == "" do
      []
    else
      inner |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&parse_toml_value/1)
    end
  end

  defp parse_toml_scalar(value) do
    cond do
      value =~ ~r/^[0-9]+$/ -> String.to_integer(value)
      value =~ ~r/^[0-9]+\.[0-9]+$/ -> String.to_float(value)
      value == "true" -> true
      value == "false" -> false
      true -> value
    end
  end

  defp serialize_toml(map) do
    map
    |> Enum.reduce([], fn {section, content}, acc ->
      section_header = "\n[#{section}]\n"
      body = Enum.map_join(content, "", fn {k, v} -> "#{k} = #{serialize_toml_value(v)}\n" end)
      acc ++ [section_header, body]
    end)
    |> Enum.join()
    |> String.trim_leading()
  end

  defp serialize_toml_value(value) do
    cond do
      is_binary(value) -> "\"#{value}\""
      is_integer(value) -> Integer.to_string(value)
      is_float(value) -> Float.to_string(value)
      is_boolean(value) -> if value, do: "true", else: "false"
      is_list(value) -> "[" ++ Enum.map_join(value, ", ", &serialize_toml_value/1) ++ "]"
      is_map(value) -> "{" ++ Enum.map_join(value, ", ", fn {k, v} -> "#{k} = #{serialize_toml_value(v)}" end) ++ "}"
      true -> to_string(value)
    end
  end

  defp extract_version(dir_name) do
    case Regex.run(~r/-([\d.]+)$/, dir_name) do
      nil -> nil
      [_, version] -> version
    end
  end

  defp safe_cmd(cmd, args, opts) do
    System.cmd(cmd, args, opts)
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, :not_found}
        _ -> reraise e, __STACKTRACE__
      end
  end
end