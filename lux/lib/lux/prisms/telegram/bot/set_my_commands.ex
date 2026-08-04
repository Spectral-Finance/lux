defmodule Lux.Prisms.Telegram.Bot.SetMyCommands do
  @moduledoc """
  A prism for changing the bot's list of commands.
  """
  use Lux.Prism

  alias Lux.Integrations.Telegram.Client

  def prism do
    %Lux.Prism{
      id: "telegram-set-my-commands",
      name: "Set Telegram Bot Commands",
      description: "Changes the list of the bot's commands.",
      input_schema: %{
        type: :object,
        properties: %{
          commands: %{
            type: :array,
            description: "A JSON-serialized list of bot commands to be set as the list of the bot's commands.",
            items: %{
              type: :object,
              properties: %{
                command: %{type: :string, description: "Text of the command, 1-32 characters."},
                description: %{type: :string, description: "Description of the command, 1-256 characters."}
              },
              required: ["command", "description"]
            }
          }
        },
        required: ["commands"]
      },
      handler: &handler/2
    }
  end

  def handler(input, _ctx) do
    case Client.request(:post, "/setMyCommands", %{json: input}) do
      {:ok, %{"result" => true}} ->
        {:ok, :success}

      {:ok, %{"result" => false}} ->
        {:error, :failed_to_set_commands}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
