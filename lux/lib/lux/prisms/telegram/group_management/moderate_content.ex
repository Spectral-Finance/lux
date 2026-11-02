defmodule Lux.Prisms.Telegram.GroupManagement.ModerateContent do
  @moduledoc """
  A prism for scanning message text and metadata for moderation violations
  and automatically executing enforcement actions.
  """

  use Lux.Prism,
    name: "Moderate Telegram Content",
    description: "Evaluates message content for spam, banned keywords, mass mentions, and executes enforcement actions",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :object, description: "Raw Telegram message payload"},
        config: %{type: :object, description: "Optional moderation config overrides"},
        execute_action: %{type: :boolean, description: "Whether to execute the recommended action immediately"}
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        violation: %{type: [:string, :null]},
        severity: %{type: :string},
        action: %{type: :string},
        executed: %{type: :boolean}
      },
      required: ["action", "executed"]
    }

  alias Lux.Integrations.Telegram.GroupManagement.ContentModerator

  def handler(params, _agent) when is_map(params) do
    message = Map.get(params, :message) || Map.get(params, "message") || params
    config = Map.get(params, :config) || Map.get(params, "config") || %{}
    execute = Map.get(params, :execute_action, false)
    plug = Map.get(params, :plug)

    with {:ok, eval} <- ContentModerator.check_content(message, config) do
      if execute and eval.recommended_action != :none do
        chat_id = get_in(message, [:chat, :id]) || get_in(message, ["chat", "id"]) || Map.get(message, :chat_id)
        message_id = Map.get(message, :message_id) || Map.get(message, "message_id")
        user_id = get_in(message, [:from, :id]) || get_in(message, ["from", "id"]) || Map.get(message, :user_id)

        opts = if plug, do: [plug: plug], else: []

        ContentModerator.enforce_action(chat_id, message_id, user_id, eval.recommended_action, opts)

        {:ok,
         %{
           violation: eval.violation && to_string(eval.violation),
           severity: to_string(eval.severity),
           action: to_string(eval.recommended_action),
           executed: true
         }}
      else
        {:ok,
         %{
           violation: eval.violation && to_string(eval.violation),
           severity: to_string(eval.severity),
           action: to_string(eval.recommended_action),
           executed: false
         }}
      end
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
