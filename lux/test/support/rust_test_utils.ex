defmodule Lux.RustTestUtils do
  @moduledoc """
  Cross-language test utilities and fixtures for Rust-Elixir integration tests.
  Provides helpers to generate standard test data structures and parse Rust output.
  """

  @doc """
  Generates a standard payload for testing Rust NIFs.
  """
  def generate_test_payload(overrides \\ %{}) do
    %{
      "id" => Ecto.UUID.generate(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => %{
        "type" => "test_event",
        "value" => 42
      }
    }
    |> Map.merge(overrides)
  end

  @doc """
  Validates a response from a Rust NIF.
  Returns {:ok, data} if valid, {:error, reason} otherwise.
  """
  def validate_rust_response({:ok, response}) when is_map(response) do
    {:ok, response}
  end

  def validate_rust_response({:ok, _other}), do: {:error, :invalid_format}
  def validate_rust_response({:error, reason}), do: {:error, reason}

  @doc """
  Helper to assert a Rust NIF returned successfully with expected data.
  """
  def assert_valid_rust_response(response, expected_key, expected_val) do
    case validate_rust_response(response) do
      {:ok, data} -> 
        if Map.get(data, expected_key) == expected_val do
          :ok
        else
          {:error, "Expected \#{expected_key} to be \#{expected_val}"}
        end
      error -> error
    end
  end
end
