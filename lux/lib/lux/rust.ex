defmodule Lux.Rust do
  @moduledoc """
  A high-performance bridge to Lux's native Rust components using Rustler.
  """
  use Rustler, otp_app: :lux, crate: "lux_rust"

  @doc """
  Dispatch calls to Rust components.
  """
  def call_handler(_input_json, _context_json), do: :erlang.nif_error(:nif_not_loaded)

  def run(input, context \\ %{}) do
    input_json = Jason.encode!(input)
    context_json = Jason.encode!(context)
    
    case call_handler(input_json, context_json) do
      {:ok, result_json} -> {:ok, Jason.decode!(result_json)}
      {:error, reason} -> {:error, reason}
      result_json when is_binary(result_json) -> {:ok, Jason.decode!(result_json)}
    end
  end
end
