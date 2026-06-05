defmodule Lux.Rust do
  @moduledoc """
  Rust native code integration for high-performance operations via NIF bindings.
  """

  def version, do: nif_version() || "unavailable"
  def ping, do: nif_ping() || "no_rust"
  def add(a, b), do: nif_add(a, b) || a + b

  use Rustler, otp_app: :lux, crate: "lux_rust"

  # Fallbacks when NIF is not compiled — arities match the Rust exports (version/0, ping/0, add/2)
  defp nif_version, do: :erlang.nif_error(:nif_not_loaded)
  defp nif_ping, do: :erlang.nif_error(:nif_not_loaded)
  defp nif_add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
