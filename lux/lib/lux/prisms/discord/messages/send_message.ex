defmodule Lux.Prisms.Discord.Messages.SendMessage do
  @moduledoc """
  A prism for sending messages to a Discord channel via the Discord REST API.
  """

  use Lux.Prism,
    name: "Send Discord Message",
    description: "Sends a message to a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Target Discord channel snowflake ID"
        },
        content: %{
          type: :string,
          description: "Text content of the message"
        },
        embeds: %{
          type: :array,
          description: "Optional rich embed objects",
          items: %{type: :object}
        },
        components: %{
          type: :array,
          description: "Optional message components",
          items: %{type: :object}
        },
        tts: %{
          type: :boolean,
          description: "Whether this is a text-to-speech message"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean},
        message_id: %{type: :string},
        channel_id: %{type: :string},
        content: %{type: :string}
      },
      required: ["sent", "message_id", "channel_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} dispatching Discord message to channel #{channel_id}")

      body =
        params
        |> Map.take([:content, :embeds, :components, :tts])
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()

      opts = %{json: body}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:post, "/channels/#{channel_id}/messages", opts) do
        {:ok, %{"id" => message_id} = response} ->
          {:ok, %{
            sent: true,
            message_id: message_id,
            channel_id: channel_id,
            content: response["content"] || params[:content] || ""
          }}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
