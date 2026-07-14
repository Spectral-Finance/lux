defmodule Lux.Prisms.Discord.Webhook.SendWebhookMessage do
  @moduledoc """
  Send a message via a Discord webhook.

  This prism allows posting messages to a Discord channel using a webhook URL.
  It supports custom content, embeds, username overrides, and avatar overrides.

  Implements the webhook message posting portion of #56 Advanced Discord Features.

  ## Examples

      iex> SendWebhookMessage.handler(%{
      ...>   webhook_url: "https://discord.com/api/webhooks/123/abc",
      ...>   content: "Hello from bot!"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: "456"}}

      iex> SendWebhookMessage.handler(%{
      ...>   webhook_url: "https://discord.com/api/webhooks/123/abc",
      ...>   content: "Deploy alert",
      ...>   username: "CI Bot",
      ...>   embeds: [%{title: "Build Passed", color: 3066993}]
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: "789"}}
  """

  use Lux.Prism,
    name: "Send Webhook Message",
    description: "Sends a message to a Discord channel via webhook",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_url: %{
          type: :string,
          description: "The full webhook URL (includes webhook ID and token)"
        },
        content: %{
          type: :string,
          description: "The message content (max 2000 characters)",
          maxLength: 2000
        },
        username: %{
          type: :string,
          description: "Override the default username of the webhook",
          maxLength: 80
        },
        avatar_url: %{
          type: :string,
          description: "Override the default avatar of the webhook"
        },
        tts: %{
          type: :boolean,
          description: "Whether the message should be posted with text-to-speech"
        },
        embeds: %{
          type: :array,
          description: "Array of embed objects for rich formatting"
        }
      },
      required: ["webhook_url"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the message was successfully sent"
        },
        message_id: %{
          type: :string,
          description: "The ID of the sent message (nil for silent pushes)"
        },
        content: %{
          type: :string,
          description: "The content that was sent"
        }
      },
      required: ["sent"]
    }

  require Logger

  @doc """
  Sends a message via a Discord webhook.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, webhook_url} <- validate_webhook_url(params),
         {:ok, body} <- build_message_body(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending webhook message")

      case do_post(webhook_url <> "?wait=true", body) do
        {:ok, %{"id" => message_id} = resp} ->
          Logger.info("Successfully sent webhook message #{message_id}")

          {:ok,
           %{
             sent: true,
             message_id: message_id,
             content: resp["content"]
           }}

        {:ok, %{"message" => message}} ->
          {:error, {400, message}}

        {:error, {status, message}} when is_binary(message) ->
          Logger.error("Webhook request failed: #{inspect({status, message})}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Webhook request failed: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  @doc """
  Sends a message via webhook without waiting for a response (silent push).
  """
  @spec handler_silent(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler_silent(params, agent) do
    with {:ok, webhook_url} <- validate_webhook_url(params),
         {:ok, body} <- build_message_body(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending silent webhook message")

      silent_url =
        if String.contains?(webhook_url, "?"),
          do: "#{webhook_url}&wait=false",
          else: "#{webhook_url}?wait=false"

      case do_post(silent_url, body) do
        {:ok, _} ->
          Logger.info("Silent webhook message sent successfully")
          {:ok, %{sent: true, message_id: nil, content: body["content"]}}

        {:error, error} ->
          Logger.error("Silent webhook request failed: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_webhook_url(params) do
    case Map.fetch(params, :webhook_url) do
      {:ok, url}
      when is_binary(url) and String.starts_with?(url, "https://discord.com/api/webhooks/") ->
        {:ok, url}

      {:ok, url} when is_binary(url) ->
        {:error,
         "webhook_url must be a valid Discord webhook URL starting with https://discord.com/api/webhooks/"}

      _ ->
        {:error, "Missing webhook_url"}
    end
  end

  defp build_message_body(params) do
    content = Map.get(params, :content)
    username = Map.get(params, :username)
    avatar = Map.get(params, :avatar_url)
    tts = Map.get(params, :tts)
    embeds = Map.get(params, :embeds)

    body = %{}
    body = if(content, do: Map.put(body, "content", content), else: body)
    body = if(username, do: Map.put(body, "username", username), else: body)
    body = if(avatar, do: Map.put(body, "avatar_url", avatar), else: body)
    body = if(tts, do: Map.put(body, "tts", tts), else: body)
    body = if(embeds, do: Map.put(body, "embeds", embeds), else: body)

    if Map.size(body) == 0 do
      {:error, "Message body is empty. At least 'content' or other fields must be provided."}
    else
      {:ok, body}
    end
  end

  defp do_post(url, body) do
    plug = Application.get_env(:lux, __MODULE__, [])[:plug]

    req = %Req.Request{
      url: url,
      method: :post,
      headers: [{"Content-Type", "application/json"}],
      json: body
    }

    result =
      req
      |> maybe_add_plug(plug)
      |> Req.request()

    case result do
      {:ok, %{status: 204}} ->
        # Discord Execute Webhook with wait=false returns 204 No Content
        Logger.info("Webhook message sent (204 No Content)")
        {:ok, %{}}

      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %{status: status, body: %{"message" => msg}}} ->
        {:error, {status, msg}}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {status, resp_body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_add_plug(req, nil), do: req

  defp maybe_add_plug(req, plug) do
    Map.update!(req, :request_options, fn opts ->
      Keyword.put(opts, :plug, plug)
    end)
  end
end
