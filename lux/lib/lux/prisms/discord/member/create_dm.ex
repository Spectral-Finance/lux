defmodule Lux.Prisms.Discord.Member.CreateDM do
  use Lux.Prism,
    name: "Create Discord DM",
    description: "Creates a direct message channel with a user",
    input_schema: %{
      type: :object,
      properties: %{
        recipient_id: %{type: :string, description: "The ID of the user to DM"}
      },
      required: ["recipient_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean},
        channel_id: %{type: :string}
      },
      required: ["created", "channel_id"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _agent) do
    recipient_id = params[:recipient_id] || params["recipient_id"]

    case Client.request(:post, "/users/@me/channels", %{json: %{recipient_id: recipient_id}}) do
      {:ok, %{"id" => channel_id}} -> {:ok, %{created: true, channel_id: channel_id}}
      {:error, error} -> {:error, error}
    end
  end
end\n