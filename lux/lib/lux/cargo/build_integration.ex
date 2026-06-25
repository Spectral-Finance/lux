defmodule Lux.Cargo.BuildIntegration do
  @moduledoc """
  Cargo build system integration for Lux.

  Integrates Cargo build pipelines with Lux's agent workflow,
  enabling Rust-based computation within the Lux framework.
  """

  @doc """
  Runs cargo build with the given profile.
  """
  @spec build(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def build(path, opts \\ []) do
    profile = Keyword.get(opts, :profile, "release")
    quiet = Keyword.get(opts, :quiet, false)

    args = if quiet, do: ["build", "--profile", profile, "--quiet"], else: ["build", "--profile", profile]

    case System.cmd("cargo", args, cd: path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  @doc """
  Runs cargo test.
  """
  @spec test(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def test(path) do
    case System.cmd("cargo", ["test"], cd: path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  @doc """
  Runs cargo check (fast compilation check).
  """
  @spec check(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def check(path) do
    case System.cmd("cargo", ["check"], cd: path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end
end
