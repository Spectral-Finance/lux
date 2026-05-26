defmodule Lux.Prisms.Telegram.Management.SetMyCommands do
  @moduledoc """
  A prism for changing the list of the bot's commands.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Set Telegram Bot Commands",
    description: "Changes the list of the bot's commands",
    input_schema: %{
      type: :object,
      properties: %{
        commands: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              command: %{type: :string, description: "Text of the command, 1-32 characters. Can contain only lowercase English letters, digits and underscores."},
              description: %{type: :string, description: "Description of the command, 1-256 characters."}
            },
            required: ["command", "description"]
          },
          description: "A list of bot commands to be set as the list of the bot's commands"
        },
        scope: %{type: :object, description: "A JSON-serialized object, describing scope of users for which the commands are relevant"},
        language_code: %{type: :string, description: "A two-letter ISO 639-1 language code"}
      },
      required: ["commands"]
    }

  def handler(params, _agent) do
    case Client.request(:post, "/setMyCommands", %{json: params}) do
      {:ok, %{"ok" => true, "result" => true}} ->
        {:ok, %{success: true}}

      {:ok, response} ->
        {:error, response}

      {:error, error} ->
        {:error, error}
    end
  end
end
