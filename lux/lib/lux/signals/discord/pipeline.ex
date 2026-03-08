defmodule Lux.Signals.Discord.Pipeline do
  @moduledoc "Signal processing pipeline for Discord signals."

  alias Lux.Signals.Discord.{MessageSignal, InteractionSignal, PresenceSignal}

  @type step :: (map() -> {:ok, map()} | {:error, term()})

  def process(signal, steps \\ []) when is_list(steps) do
    Enum.reduce_while(steps, {:ok, signal}, fn step, {:ok, acc} ->
      case step.(acc) do
        {:ok, result} -> {:cont, {:ok, result}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def classify(payload) when is_map(payload) do
    cond do
      Map.has_key?(payload, "content") || Map.has_key?(payload, :content) -> {:ok, :message}
      Map.has_key?(payload, "type") && is_integer(payload["type"]) -> {:ok, :interaction}
      Map.has_key?(payload, "status") || Map.has_key?(payload, :status) -> {:ok, :presence}
      true -> {:error, :unknown_signal}
    end
  end

  def parse(payload) do
    case classify(payload) do
      {:ok, :message} -> MessageSignal.from_discord(payload)
      {:ok, :interaction} -> InteractionSignal.from_discord(payload)
      {:ok, :presence} -> PresenceSignal.from_discord(payload)
      error -> error
    end
  end
end
