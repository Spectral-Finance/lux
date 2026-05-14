defmodule Lux.Rust.Core do
  @moduledoc """
  Minimal Rust core bridge for Lux.

  The bridge invokes the checked-in `priv/rust/lux_core` Cargo crate through a
  JSON/base64 command boundary. This keeps the first Rust integration portable
  and reviewable while establishing the project structure, conversion rules, and
  explicit error propagation needed for future NIF or Rustler work.
  """

  @default_manifest_path Path.expand("../../../priv/rust/lux_core/Cargo.toml", __DIR__)

  @type native_error :: %{code: String.t(), message: String.t()}

  @doc """
  Runs a native Rust operation with a JSON-compatible input value.
  """
  @spec execute(String.t() | atom(), term(), keyword()) ::
          {:ok, term()} | {:error, native_error()}
  def execute(operation, input, opts \\ []) do
    cargo = Keyword.get(opts, :cargo, "cargo")
    manifest_path = Keyword.get(opts, :manifest_path, @default_manifest_path)

    payload =
      input
      |> Jason.encode!()
      |> Base.encode64()

    args = [
      "run",
      "--quiet",
      "--manifest-path",
      manifest_path,
      "--",
      to_string(operation),
      payload
    ]

    case System.cmd(cargo, args, stderr_to_stdout: true) do
      {output, 0} ->
        decode_response(output)

      {output, _exit_code} ->
        case decode_response(output) do
          {:ok, value} -> {:error, %{code: "native_exit", message: inspect(value)}}
          {:error, error} -> {:error, error}
        end
    end
  rescue
    error in ErlangError ->
      {:error, %{code: "native_runtime_error", message: Exception.message(error)}}
  end

  @doc """
  Returns the Rust bridge command plan without executing it.
  """
  @spec command_plan(String.t() | atom(), term(), keyword()) :: map()
  def command_plan(operation, input, opts \\ []) do
    manifest_path = Keyword.get(opts, :manifest_path, @default_manifest_path)

    payload =
      input
      |> Jason.encode!()
      |> Base.encode64()

    %{
      command: [
        Keyword.get(opts, :cargo, "cargo"),
        "run",
        "--quiet",
        "--manifest-path",
        manifest_path,
        "--",
        to_string(operation),
        payload
      ],
      manifest_path: manifest_path
    }
  end

  @doc """
  Convenience wrapper for the Rust `type_of` operation.
  """
  @spec type_of(term(), keyword()) :: {:ok, String.t()} | {:error, native_error()}
  def type_of(value, opts \\ []) do
    with {:ok, %{"type" => type}} <- execute(:type_of, value, opts) do
      {:ok, type}
    end
  end

  @doc """
  Convenience wrapper for the Rust `sum_i64` operation.
  """
  @spec sum_i64([integer()], keyword()) :: {:ok, integer()} | {:error, native_error()}
  def sum_i64(values, opts \\ []) do
    with {:ok, %{"sum" => sum}} <- execute(:sum_i64, values, opts) do
      {:ok, sum}
    end
  end

  @doc """
  Checks whether the Rust Cargo project is present.
  """
  @spec native_available?(keyword()) :: boolean()
  def native_available?(opts \\ []) do
    opts
    |> Keyword.get(:manifest_path, @default_manifest_path)
    |> File.exists?()
  end

  defp decode_response(output) do
    output
    |> String.split("\n", trim: true)
    |> List.last()
    |> Jason.decode()
    |> case do
      {:ok, %{"ok" => true, "value" => value}} ->
        {:ok, value}

      {:ok, %{"ok" => false, "error" => %{"code" => code, "message" => message}}} ->
        {:error, %{code: code, message: message}}

      {:ok, other} ->
        {:error, %{code: "invalid_native_response", message: inspect(other)}}

      {:error, error} ->
        {:error, %{code: "invalid_native_output", message: Exception.message(error)}}
    end
  end
end
