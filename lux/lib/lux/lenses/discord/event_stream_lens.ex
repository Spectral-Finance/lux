defmodule Lux.Lenses.Discord.EventStreamLens do
  use Lux.Lens,
    name: "Discord Event Stream Lens",
    description: "Decodes Discord Gateway WebSocket payloads.",
    url: "wss://gateway.discord.gg"

  @doc """
  Decodes a Discord Gateway JSON payload map into a structured map.
  """
  def after_focus(payload) when is_map(payload) do
    decoded = %{
      op: Map.get(payload, "op"),
      data: Map.get(payload, "d"),
      sequence: Map.get(payload, "s"),
      type: Map.get(payload, "t")
    }

    {:ok, decoded}
  end

  def after_focus(error), do: {:error, error}
end
