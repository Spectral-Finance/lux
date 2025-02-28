defmodule TestSignalSchema do
  @moduledoc """
  This module defines a schema for testing.
  """

  use Lux.SignalSchema,
    id: "test-schema",
    name: "Test Schema",
    description: "A test schema for reflection tests",
    created_by: "test developer",
    created_at: DateTime.utc_now(),
    tags: ["test", "schema"],
    compatibility: :full,
    status: :active,
    format: :json,
    schema: %{
      type: :object,
      required: [],
      properties: %{
        message: %{type: :string}
      }
    }

  def validate(%{payload: %{wrong: _}} = _signal) do
    {:error, "Invalid content"}
  end

  def validate(signal), do: {:ok, signal}
end
