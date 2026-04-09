defmodule Lux.Native do
  use Rustler,
    otp_app: :lux,
    crate: "lux_native"

  @doc """
  Returns a list of all registered Rust components.
  """
  def list_components, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Calls a registered Rust component by name with the given input.
  """
  def call_component(_name, _input), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns metadata about a registered Rust component.
  """
  def get_component_info(_name), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  High-level wrapper to call a Rust component.
  Returns {:ok, result} or {:error, reason}.
  """
  def call(name, input) do
    try do
      {:ok, call_component(name, input)}
    rescue
      e in ErlangError ->
        case e.original do
          :component_not_found -> {:error, "Component '#{name}' not found"}
          reason -> {:error, reason}
        end
      other ->
        {:error, inspect(other)}
    end
  end
end
