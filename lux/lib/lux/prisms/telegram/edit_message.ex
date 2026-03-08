defmodule Lux.Prisms.Telegram.EditMessage do
  @moduledoc """
  Prism for editing messages in Telegram.
  """

  use Lux.Prism,
    name: "Telegram Edit Message",
    description: "Edit a sent message",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer]},
        message_id: %{type: :integer},
        text: %{type: :string},
        parse_mode: %{type: :string},
        reply_markup: %{type: :object},
        token: %{type: :string}
      },
      required: ["chat_id", "message_id", "text", "token"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _opts) do
    api_params =
      %{
        chat_id: params[:chat_id] || params["chat_id"],
        message_id: params[:message_id] || params["message_id"],
        text: params[:text] || params["text"]
      }
      |> maybe_put(:parse_mode, params[:parse_mode] || params["parse_mode"])
      |> maybe_put(:reply_markup, params[:reply_markup] || params["reply_markup"])

    Client.request("editMessageText", api_params, build_opts(params))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
