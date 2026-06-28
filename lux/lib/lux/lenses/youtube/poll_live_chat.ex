defmodule Lux.Lenses.YouTube.PollLiveChat do
  @moduledoc """
  Polls messages from a YouTube Live Chat. Returns `nextPageToken` and `pollingIntervalMillis`
  to respect YouTube's rate limits and pagination requirements.
  """
  @behaviour Lux.Lens

  def view do
    Lux.Lens.new(
      name: "YouTube Poll Live Chat",
      description: "Fetches live chat messages for a specific broadcast. Use nextPageToken from previous responses to paginate.",
      schema: %{
        type: :object,
        properties: %{
          live_chat_id: %{
            type: :string,
            description: "The ID of the live chat."
          },
          page_token: %{
            type: :string,
            description: "The nextPageToken from the previous poll. Omit for the first request."
          }
        },
        required: ["live_chat_id"]
      }
    )
  end

  alias Lux.Integrations.YouTube.LiveChat
  alias Lux.Integrations.YouTube.Client

  def focus(params, _context) do
    # Normalize string keys to atom keys
    live_chat_id = Map.get(params, "live_chat_id") || Map.get(params, :live_chat_id)
    page_token = Map.get(params, "page_token") || Map.get(params, :page_token)

    config = Client.default_config()

    case LiveChat.list_messages(live_chat_id, page_token, config) do
      {:ok, response} ->
        {:ok, %{
          messages: response["items"] || [],
          next_page_token: response["nextPageToken"],
          polling_interval_millis: response["pollingIntervalMillis"]
        }}

      error ->
        error
    end
  end
end
