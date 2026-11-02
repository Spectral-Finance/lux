defmodule Lux.Prisms.Twitter.Automation.AutomateDM do
  @moduledoc """
  A prism for generating welcome DMs and processing inbound messages with keyword FAQs and opt-outs.
  """

  use Lux.Prism,
    name: "Automate Twitter DMs",
    description: "Generates follower welcome direct messages and parses inbound DMs for FAQ responses or opt-outs",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "'welcome' or 'process_inbound'"},
        user: %{type: :object, description: "Follower profile for welcome DM"},
        message: %{type: :object, description: "Inbound DM payload"},
        opted_out_users: %{type: :array, description: "List of opted-out user IDs"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        action_required: %{type: :string},
        text: %{type: [:string, :null]}
      },
      required: ["status", "action_required"]
    }

  alias Lux.Integrations.Twitter.Automation.DMAutomation

  def handler(params, _agent) when is_map(params) do
    action = to_string(Map.get(params, :action) || Map.get(params, "action", "welcome"))

    case action do
      "welcome" ->
        user = Map.get(params, :user) || Map.get(params, "user", %{})
        welcome_text = DMAutomation.generate_welcome_message(user)

        {:ok,
         %{
           status: "welcome_generated",
           action_required: "send_dm",
           text: welcome_text
         }}

      "process_inbound" ->
        dm = Map.get(params, :message) || Map.get(params, "message", %{})
        opted_out = MapSet.new(Map.get(params, :opted_out_users) || Map.get(params, "opted_out_users", []))

        {:ok, res, _new_set} = DMAutomation.process_message(dm, opted_out)

        {:ok,
         %{
           status: "processed",
           action_required: to_string(res.action),
           text: Map.get(res, :reply_text)
         }}

      other ->
        {:error, "Unsupported action: #{other}"}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
