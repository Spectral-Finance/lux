defmodule Lux.Prisms.Telegram.SendMedia do
  @moduledoc """
  Prism for sending media (photos, documents, voice, video, audio) via Telegram.
  """

  use Lux.Prism,
    name: "Telegram Send Media",
    description: "Send photos, documents, voice, video, or audio to a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer]},
        media_type: %{type: :string, enum: ["photo", "document", "voice", "video", "audio"]},
        media: %{type: :string, description: "File ID, URL, or file path"},
        caption: %{type: :string},
        parse_mode: %{type: :string},
        reply_to_message_id: %{type: :integer},
        token: %{type: :string}
      },
      required: ["chat_id", "media_type", "media", "token"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Telegram.Client

  @media_methods %{
    "photo" => "sendPhoto",
    "document" => "sendDocument",
    "voice" => "sendVoice",
    "video" => "sendVideo",
    "audio" => "sendAudio"
  }

  @media_fields %{
    "photo" => "photo",
    "document" => "document",
    "voice" => "voice",
    "video" => "video",
    "audio" => "audio"
  }

  @impl true
  def handler(params, _opts) do
    media_type = params[:media_type] || params["media_type"]
    media = params[:media] || params["media"]
    method = @media_methods[media_type]
    field = @media_fields[media_type]

    unless method, do: raise("Unknown media type: #{media_type}")

    api_params =
      %{chat_id: params[:chat_id] || params["chat_id"]}
      |> Map.put(String.to_atom(field), media)
      |> maybe_put(:caption, params[:caption] || params["caption"])
      |> maybe_put(:parse_mode, params[:parse_mode] || params["parse_mode"])
      |> maybe_put(:reply_to_message_id, params[:reply_to_message_id] || params["reply_to_message_id"])

    Client.request(method, api_params, build_opts(params))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
