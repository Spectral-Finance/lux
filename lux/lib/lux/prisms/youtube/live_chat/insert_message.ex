defmodule Lux.Prisms.YouTube.LiveChat.InsertMessage do
  @moduledoc "Sends text messages to a YouTube live chat."

  use Lux.Prism,
    name: "Send YouTube Live Chat Message",
    description: "Sends a textMessageEvent into an active YouTube live chat",
    input_schema: %{
      type: :object,
      properties: %{live_chat_id: %{type: :string}, text: %{type: :string}},
      required: ["live_chat_id", "text"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, live_chat_id} <- required(params, :live_chat_id),
         {:ok, text} <- required(params, :text),
         {:ok, response} <- Client.request(:post, "/liveChat/messages", %{
           params: %{part: "snippet"},
           json: %{
             snippet: %{
               liveChatId: live_chat_id,
               type: "textMessageEvent",
               textMessageDetails: %{messageText: text}
             }
           }
         }) do
      snippet = response["snippet"] || %{}
      {:ok, %{id: response["id"], message: snippet["displayMessage"] || text}}
    end
  end

  defp required(params, key) do
    case Map.get(params, key) || Map.get(params, to_string(key)) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
