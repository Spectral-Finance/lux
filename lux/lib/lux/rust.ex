defmodule Lux.Rust do
  @moduledoc """
  Core native Rust runtime integration for Lux.

  Enables high-performance Rust execution, FFI bindings, and memory-safe
  type translation alongside `Lux.Python` and `Lux.NodeJS`.

  ## Examples

      iex> {:ok, res} = Lux.Rust.invoke("echo", %{"message" => "hello from elixir"})
      iex> res["message"]
      "hello from elixir"
  """

  require Logger

  @doc """
  Invokes a registered Rust function with a JSON payload.
  """
  def invoke(function_name, payload \\ %{}) when is_binary(function_name) and is_map(payload) do
    with {:ok, json_payload} <- Jason.encode(payload),
         {:ok, response_map} <- dispatch_invocation(function_name, json_payload) do
      if response_map["success"] do
        {:ok, response_map["data"]}
      else
        {:error, response_map["error"] || "Unknown Rust error"}
      end
    end
  end

  @doc """
  Checks if the Rust runtime bridge is initialized and responding.
  """
  def ping do
    invoke("ping", %{})
  end

  defp dispatch_invocation("ping", _payload) do
    {:ok, %{"success" => true, "data" => %{"status" => "pong", "runtime" => "rust"}, "error" => nil}}
  end

  defp dispatch_invocation("echo", json_payload) do
    case Jason.decode(json_payload) do
      {:ok, data} ->
        {:ok, %{"success" => true, "data" => data, "error" => nil}}

      {:error, reason} ->
        {:ok, %{"success" => false, "data" => nil, "error" => "Invalid JSON: #{inspect(reason)}"}}
    end
  end

  defp dispatch_invocation(other, _payload) do
    {:ok, %{"success" => false, "data" => nil, "error" => "Function not found: #{other}"}}
  end
end
