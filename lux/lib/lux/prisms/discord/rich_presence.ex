defmodule Lux.Prisms.Discord.RichPresence do
  @moduledoc """
  Set custom rich presence activity for the bot on Discord.

  Uses the Discord Gateway bot presence update endpoint.
  Requires Identify and Presence Update intents.
  """

  @spec set_presence(Lux.Lens.t(), binary(), binary(), list(binary())) :: {:ok, map} | {:error, binary()}
  def set_presence(%Lux.Lens{} = lens, activity_name, activity_type, state) do
    types = %{
      "playing" => 0,
      "streaming" => 1,
      "listening" => 2,
      "watching" => 3,
      "competing" => 5
    }

    type_code = Map.get(types, activity_type, 0)

    body = %{
      "status" => "online",
      "activities" => [
        %{
          "name" => activity_name,
          "type" => type_code,
          "state" => state
        }
      ]
    }

    lens
    |> Lux.Lens.put(:method, :patch)
    |> Lux.Lens.put(:url, "https://discord.com/api/v10/users/@me/presence")
    |> Lux.Lens.put(:body, body)
    |> Lux.Lens.execute()
  end
end
