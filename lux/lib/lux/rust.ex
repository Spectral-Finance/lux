defmodule Lux.Rust do
  @moduledoc """
  Rust language support for Lux.

  This namespace hosts helpers for Rust projects that are used by Lux agents,
  prisms, and native integrations.
  """

  @module_path Application.app_dir(:lux, "priv/rust")

  @doc """
  Returns the default Rust project directory for Lux.
  """
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @doc """
  Checks whether Cargo is available in the current environment.
  """
  @spec available?() :: boolean()
  defdelegate available?(), to: Lux.Rust.Cargo

  @doc """
  Returns Cargo and Rust toolchain version information.
  """
  @spec version(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate version(opts \\ []), to: Lux.Rust.Cargo

  @doc """
  Builds the configured Cargo project.
  """
  @spec build(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate build(opts \\ []), to: Lux.Rust.Cargo

  @doc """
  Fetches dependencies for the configured Cargo project.
  """
  @spec fetch(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate fetch(opts \\ []), to: Lux.Rust.Cargo

  @doc """
  Runs Cargo tests for the configured Cargo project.
  """
  @spec test(keyword() | map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate test(opts \\ []), to: Lux.Rust.Cargo
end
