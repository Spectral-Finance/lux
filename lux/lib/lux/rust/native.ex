defmodule Lux.Rust.Native do
  @moduledoc """
  NIF stubs for Rust integration.

  This module contains the NIF function definitions that are replaced
  by the actual Rust implementations when the NIF is loaded.

  Do not call these functions directly - use `Lux.Rust` instead.
  """

  @doc false
  def execute(_func_name, _args) do
    {:error, :nif_not_loaded}
  end

  @doc false
  def eval(_expression, _variables) do
    {:error, :nif_not_loaded}
  end

  @doc false
  def version do
    %{"version" => "nif_not_loaded", "rustc" => "unknown", "target" => "unknown"}
  end

  @doc false
  def health_check do
    {:error, :nif_not_loaded}
  end
end
