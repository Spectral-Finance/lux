defmodule Lux.Signals.Discord do
  @moduledoc """
  Schema definitions and validation for Discord-related signals.
  """

  defstruct [:type, :payload, :metadata]

  @type t :: %__MODULE__{type: atom(), payload: map(), metadata: map()}

  @doc """
  Validates and converts raw Discord data into a Lux Signal.
  """
  def from_discord(type, data) when is_map(data) do
    case validate_payload(type, data) do
      {:ok, payload} -> {:ok, %__MODULE__{type: type, payload: payload, metadata: Map.get(data, :metadata, %{})}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_payload(:message, data), do: {:ok, Map.take(data, [:content, :attachments, :embeds, :components])}
  defp validate_payload(:interaction, data), do: {:ok, Map.take(data, [:command, :button_id, :values, :modal_data])}
  defp validate_payload(:presence, data), do: {:ok, Map.take(data, [:status, :activities])}
  defp validate_payload(_, _), do: {:error, :unknown_signal_type}
end