defmodule Lux.Native do
  @moduledoc """
  Rust Core Integration for Lux.

  Provides native Rust NIFs for high-performance computations,
  type system, testing framework, and component definitions.
  """

  use Rustler, otp_app: :lux, crate: :lux_native

  # --- Core NIFs (#94) ---
  def hash_sha256(_data), do: error()
  def serialize_json(_data), do: error()
  def deserialize_json(_data), do: error()
  def type_to_string(_term), do: error()
  def add_numbers(_a, _b), do: error()
  def multiply_numbers(_a, _b), do: error()

  # --- Cargo Management (#100) ---
  def cargo_generate_toml(_name, _version, _deps), do: error()
  def cargo_resolve_deps(_toml), do: error()

  # --- Type System (#101) ---
  def type_serialize(_value, _target_type), do: error()
  def type_make_struct(_fields), do: error()

  # --- Testing Framework (#102) ---
  def test_parse_and_run(_test_code), do: error()
  def test_generate_fixture(_name, _data), do: error()

  # --- Component System (#103) ---
  def component_register(_name, _config_json), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
