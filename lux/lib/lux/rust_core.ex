defmodule Lux.RustCore do
  @moduledoc """
  Core Rust integration for Lux.

  This module provides high-performance native code execution and FFI bindings.
  It relies on Rustler to seamlessly interact with the underlying Rust code.
  """
  use Rustler, otp_app: :lux, crate: "lux_core"

  @doc """
  A basic example of type conversion and FFI bindings.
  Accepts two integers, securely adds them in Rust, and returns the result.
  """
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Example to demonstrate error handling framework with proper propagation.
  Accepts a string, processes it in Rust, and safely returns it.
  """
  def compute_complex_task(_data), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Executes a Rust component asynchronously.
  This demonstrates lifecycle management and execution of native Rust components.
  """
  def execute_math_prism(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
