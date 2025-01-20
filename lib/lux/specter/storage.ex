defmodule Lux.Specter.Storage do
  @moduledoc """
  Behavior for Specter storage implementations.
  Provides a common interface for storing and retrieving specter definitions and state.
  """

  @type specter_id :: String.t()
  @type serialized_data :: binary()
  @type storage_opts :: keyword()

  @callback init(storage_opts()) :: {:ok, term()} | {:error, term()}
  @callback store(term(), specter_id(), serialized_data()) :: :ok | {:error, term()}
  @callback fetch(term(), specter_id()) :: {:ok, serialized_data()} | {:error, term()}
  @callback delete(term(), specter_id()) :: :ok | {:error, term()}
  @callback list(term()) :: {:ok, [specter_id()]} | {:error, term()}

  @doc """
  Serializes a specter struct into binary format.
  Uses Erlang's term_to_binary for efficient serialization.
  """
  def serialize(%Lux.Specter{} = specter) do
    {:ok, :erlang.term_to_binary(specter)}
  end

  @doc """
  Deserializes binary data back into a specter struct.
  """
  def deserialize(binary) when is_binary(binary) do
    try do
      specter = :erlang.binary_to_term(binary)
      {:ok, specter}
    rescue
      e -> {:error, {:deserialization_failed, e}}
    end
  end
end
