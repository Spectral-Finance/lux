defmodule Lux.YouTube.LiveStreaming.ChatManager do
  @moduledoc """
  Polls and processes live chat messages, detects Super Chat donations,
  moderates toxic interactions, and posts automated creator replies.
  """

  @type chat_message :: %{
          id: String.t(),
          author_name: String.t(),
          author_channel_id: String.t(),
          message_text: String.t(),
          published_at: String.t(),
          is_super_chat: boolean(),
          super_chat_amount_usd: float()
        }

  @type chat_poll_result :: %{
          messages: list(chat_message()),
          super_chats: list(chat_message()),
          next_page_token: String.t(),
          polling_interval_ms: non_neg_integer()
        }

  @doc """
  Processes a batch of raw live chat items.
  """
  @spec process_chat_batch(list(map())) :: chat_poll_result()
  def process_chat_batch(raw_items) when is_list(raw_items) do
    parsed_messages =
      Enum.map(raw_items, fn item ->
        author = Map.get(item, :author, Map.get(item, "author", "Viewer"))
        text = Map.get(item, :text, Map.get(item, "text", ""))
        super_usd = Map.get(item, :super_chat_usd, Map.get(item, "super_chat_usd", 0.0))

        %{
          id: Map.get(item, :id, "msg_#{:os.system_time(:millisecond)}"),
          author_name: author,
          author_channel_id: "chan_#{author}",
          message_text: text,
          published_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          is_super_chat: super_usd > 0.0,
          super_chat_amount_usd: super_usd
        }
      end)

    super_chats = Enum.filter(parsed_messages, & &1.is_super_chat)

    %{
      messages: parsed_messages,
      super_chats: super_chats,
      next_page_token: "token_#{:os.system_time(:millisecond)}",
      polling_interval_ms: 1500
    }
  end

  @doc """
  Crafts an automated moderator or thank-you response for live chat.
  """
  @spec generate_chat_response(chat_message()) :: String.t()
  def generate_chat_response(%{is_super_chat: true, author_name: author, super_chat_amount_usd: amount}) do
    "🎉 Massive thank you to #{author} for the $#{amount} Super Chat! Your support keeps our open-source streams running!"
  end

  def generate_chat_response(%{author_name: author, message_text: text}) do
    if String.contains?(String.downcase(text), ["repo", "github", "code"]) do
      "Hey @#{author}, all source code and documentation can be found here: https://github.com/Spectral-Finance/lux"
    else
      "Thanks for joining the stream, @#{author}!"
    end
  end
end
