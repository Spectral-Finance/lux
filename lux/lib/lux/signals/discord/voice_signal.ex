defmodule Lux.Signals.Discord.VoiceSignal do
  @moduledoc """
  A Lux Signal encapsulating a Discord voice activity or connection event.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.Discord.VoiceSignalSchema
end
