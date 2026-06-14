defmodule Lux.Prisms.Telegram.Group.GetAdmins do
  @moduledoc """
  A prism for getting the list of administrators in a Telegram group.
  """

  use Lux.Prism,
    name: "Get Telegram Admins",
    description: "Gets the list of administrators in a Telegram group",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat ID"}
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        admins: %{type: :array},
        count: %{type: :integer}
      },
      required: ["status", "admins", "count"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} getting admins for chat #{chat_id}")

      case Client.request(:post, "/getChatAdministrators", %{json: %{chat_id: chat_id}}) do
        {:ok, %{"result" => admins}} ->
          {:ok, %{status: "success", admins: admins, count: length(admins)}}
        {:error, {status, %{"description" => desc}}} ->
          {:error, "Failed to get admins: #{desc} (HTTP #{status})"}
        {:error, error} ->
          {:error, "Failed to get admins: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end