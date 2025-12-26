defmodule Lux.Lenses.Twitter.SendDirectMessage do
  @moduledoc """
  Lens for sending a Direct Message to a Twitter user.

  ## Examples
      Lux.Lenses.Twitter.SendDirectMessage.focus(%{
        participant_id: "987654321",
        text: "Hello, this is a DM from Lux!"
      })
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Send Direct Message",
    description: "Send a Direct Message to a Twitter user",
    url: "https://api.twitter.com/2/dm_conversations/with/:participant_id/messages",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        participant_id: %{type: :string, description: "The user ID to send the DM to"},
        text: %{type: :string, description: "The message text"}
      },
      required: ["participant_id", "text"]
    }

  @impl true
  def before_focus(params) do
    participant_id = Map.get(params, :participant_id) || Map.get(params, "participant_id")
    text = Map.get(params, :text) || Map.get(params, "text")

    url = String.replace(
      "https://api.twitter.com/2/dm_conversations/with/:participant_id/messages",
      ":participant_id",
      participant_id
    )

    {:ok, %{
      url: url,
      json: %{text: text}
    }}
  end

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok,
     %{
       dm_conversation_id: data["dm_conversation_id"],
       dm_event_id: data["dm_event_id"]
     }}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
