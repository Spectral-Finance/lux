defmodule Lux.Prisms.Telegram.Processing.HandleDeepLink do
  @moduledoc """
  Handles deep linking payloads passed to the bot.
  """
  use Lux.Prism,
    name: "Handle Telegram Deep Link",
    description: "Extracts deep link payload from /start commands",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Message text containing a command"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_deep_link: %{type: :boolean},
        payload: %{type: :string}
      },
      required: ["is_deep_link"]
    }

  def handler(params, _ctx) do
    text = Map.get(params, :text) || Map.get(params, "text") || ""
    text = String.trim(text)

    # Deep links come as "/start payload"
    if String.starts_with?(text, "/start ") do
      [_, payload] = String.split(text, " ", parts: 2)
      
      {:ok, %{
        is_deep_link: true,
        payload: payload
      }}
    else
      {:ok, %{
        is_deep_link: false,
        payload: nil
      }}
    end
  end
end
