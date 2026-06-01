defmodule Lux.Lenses.YouTube.LiveChat.ListMessages do
  @moduledoc """
  Lists YouTube live chat messages with pagination metadata.
  """

  alias Lux.Integrations.YouTube.LiveWorkflow

  def view do
    Lux.Lens.new(
      name: "List YouTube Live Chat Messages",
      module_name: inspect(__MODULE__),
      description: "Lists live chat messages and returns next page/polling metadata",
      schema: %{
        type: :object,
        properties: %{
          live_chat_id: %{type: :string},
          page_token: %{type: :string},
          max_results: %{type: :integer},
          access_token: %{type: :string}
        },
        required: ["live_chat_id", "access_token"]
      }
    )
  end

  def focus(input, _opts \\ %{}) do
    LiveWorkflow.list_chat_messages(
      input[:live_chat_id] || input["live_chat_id"],
      input
    )
  end
end
