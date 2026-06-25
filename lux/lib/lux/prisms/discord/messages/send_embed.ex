defmodule Lux.Prisms.Discord.Messages.SendEmbed do
  @moduledoc """
  A prism for sending rich embed messages to Discord channels.

  Extends the basic SendMessage prism with Discord embed support:
  title, description, color, fields, author, footer, and thumbnail.

  ## Examples

      iex> SendEmbed.handler(%{
      ...>   channel_id: "123456789012345678",
      ...>   title: "Status Update",
      ...>   description: "All systems operational",
      ...>   color: 0x00FF00,
      ...>   fields: [{"Uptime", "99.9%", true}]
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: "...", channel_id: "123456789012345678"}}
  """

  use Lux.Prism,
    name: "Send Discord Embed",
    description: "Sends a rich embed message to a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Discord channel ID",
          pattern: "^[0-9]{17,20}$"
        },
        title: %{type: :string, description: "Embed title (max 256 chars)"},
        description: %{type: :string, description: "Embed description (max 4096 chars)"},
        color: %{type: :integer, description: "Embed color as decimal integer (e.g. 65280 for green)"},
        url: %{type: :string, description: "URL the title links to"},
        fields: %{
          type: :array,
          description: "List of {name, value, inline} field tuples (max 25)"
        },
        footer_text: %{type: :string, description: "Footer text"},
        author_name: %{type: :string, description: "Author display name"},
        thumbnail_url: %{type: :string, description: "Thumbnail image URL"},
        image_url: %{type: :string, description: "Main image URL"},
        content: %{type: :string, description: "Plain text content outside the embed"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean},
        message_id: %{type: :string},
        channel_id: %{type: :string}
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @impl true
  def handler(%{channel_id: channel_id} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} sending embed to channel #{channel_id}")

    embed = build_embed(params)
    body = %{embeds: [embed]}
    body = if Map.has_key?(params, :content), do: Map.put(body, :content, params.content), else: body

    case Client.request(:post, "/channels/#{channel_id}/messages", %{json: body}) do
      {:ok, %{"id" => message_id}} ->
        Logger.info("Sent embed #{message_id} to channel #{channel_id}")
        {:ok, %{sent: true, message_id: message_id, channel_id: channel_id}}

      {:error, {status, %{"message" => message}}} ->
        Logger.error("Failed to send embed to #{channel_id}: #{status} #{message}")
        {:error, {status, message}}

      {:error, error} ->
        Logger.error("Failed to send embed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp build_embed(params) do
    embed = %{}
    embed = if Map.has_key?(params, :title),         do: Map.put(embed, :title, params.title),                           else: embed
    embed = if Map.has_key?(params, :description),   do: Map.put(embed, :description, params.description),               else: embed
    embed = if Map.has_key?(params, :color),         do: Map.put(embed, :color, params.color),                           else: embed
    embed = if Map.has_key?(params, :url),           do: Map.put(embed, :url, params.url),                               else: embed
    embed = if Map.has_key?(params, :image_url),     do: Map.put(embed, :image, %{url: params.image_url}),               else: embed
    embed = if Map.has_key?(params, :thumbnail_url), do: Map.put(embed, :thumbnail, %{url: params.thumbnail_url}),       else: embed
    embed = if Map.has_key?(params, :author_name),   do: Map.put(embed, :author, %{name: params.author_name}),           else: embed
    embed = if Map.has_key?(params, :footer_text),   do: Map.put(embed, :footer, %{text: params.footer_text}),           else: embed
    embed = if Map.has_key?(params, :fields) and is_list(params.fields) do
      fields = Enum.map(params.fields, fn
        {name, value, inline} -> %{name: name, value: value, inline: inline}
        %{name: n, value: v} = f -> Map.put_new(f, :inline, false)
        _ -> nil
      end) |> Enum.reject(&is_nil/1)
      Map.put(embed, :fields, fields)
    else
      embed
    end
    embed
  end
end
