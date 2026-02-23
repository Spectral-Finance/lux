defmodule Lux.Prisms.Telegram.Messages.GenerateDeepLink do
  @moduledoc """
  A prism for generating Telegram bot deep links.

  Creates deep links for Telegram bots that pre-fill start parameters,
  enabling features like referral tracking, onboarding flows, and
  direct group/channel invite links.

  ## Implementation Details

  - Generates t.me/botname?start=payload links (private chat)
  - Generates t.me/botname?startgroup=payload links (group invite)
  - Generates t.me/botname?startchannel=payload links (channel invite)
  - Parses existing deep links to extract parameters
  - Pure computation — no API call required

  ## Examples

      iex> GenerateDeepLink.handler(%{bot_username: "mybot", payload: "ref_abc123"}, %{})
      {:ok, %{url: "https://t.me/mybot?start=ref_abc123", type: "private", payload: "ref_abc123"}}

      iex> GenerateDeepLink.handler(%{bot_username: "mybot", payload: "invite", type: "group"}, %{})
      {:ok, %{url: "https://t.me/mybot?startgroup=invite", type: "group", payload: "invite"}}

      iex> GenerateDeepLink.handler(%{parse: "https://t.me/mybot?start=ref_abc"}, %{})
      {:ok, %{bot_username: "mybot", payload: "ref_abc", type: "private"}}
  """

  use Lux.Prism,
    name: "Generate Telegram Deep Link",
    description: "Generates or parses Telegram bot deep links for start parameters, group invites, and referral tracking",
    input_schema: %{
      type: :object,
      properties: %{
        bot_username: %{
          type: :string,
          description: "The bot's username (without @)"
        },
        payload: %{
          type: :string,
          description: "The start parameter payload (max 64 chars, alphanumeric + - _)"
        },
        type: %{
          type: :string,
          description: "Link type: 'private' (default), 'group', or 'channel'",
          enum: ["private", "group", "channel"]
        },
        parse: %{
          type: :string,
          description: "An existing deep link URL to parse (extracts payload and type)"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        url: %{type: :string, description: "The generated deep link URL"},
        type: %{type: :string, description: "The link type"},
        payload: %{type: :string, description: "The start payload"},
        bot_username: %{type: :string, description: "The bot username (when parsing)"}
      }
    }

  @base_url "https://t.me"
  @parse_regex ~r|^https?://t\.me/([^?/]+)\?start(group|channel)?=([^&]+)|

  @impl true
  def handler(%{parse: url} = _params, _agent) do
    url = to_string(url)
    case Regex.run(@parse_regex, url) do
      [_, bot, "", payload] ->
        {:ok, %{bot_username: bot, payload: URI.decode(payload), type: "private"}}
      [_, bot, nil, payload] ->
        {:ok, %{bot_username: bot, payload: URI.decode(payload), type: "private"}}
      [_, bot, "group", payload] ->
        {:ok, %{bot_username: bot, payload: URI.decode(payload), type: "group"}}
      [_, bot, "channel", payload] ->
        {:ok, %{bot_username: bot, payload: URI.decode(payload), type: "channel"}}
      _ ->
        {:error, "Invalid Telegram deep link URL: #{url}"}
    end
  end

  def handler(%{"parse" => url} = params, agent) do
    handler(%{parse: url} |> Map.merge(Map.drop(params, ["parse"])), agent)
  end

  def handler(params, _agent) do
    bot_username = params[:bot_username] || params["bot_username"]
    payload = to_string(params[:payload] || params["payload"] || "")
    type = to_string(params[:type] || params["type"] || "private")

    with {:ok, bot} <- validate_bot_username(bot_username),
         {:ok, p} <- validate_payload(payload) do
      param_key = param_key_for(type)
      url = "#{@base_url}/#{bot}?#{param_key}=#{URI.encode(p)}"
      {:ok, %{url: url, type: type, payload: p}}
    end
  end

  defp validate_bot_username(nil), do: {:error, "bot_username is required"}
  defp validate_bot_username(""), do: {:error, "bot_username cannot be empty"}
  defp validate_bot_username(username) do
    clean = String.trim_leading(to_string(username), "@")
    if Regex.match?(~r/^[A-Za-z0-9_]{3,}$/, clean) do
      {:ok, clean}
    else
      {:error, "Invalid bot username: #{username}"}
    end
  end

  defp validate_payload(""), do: {:ok, ""}
  defp validate_payload(payload) when byte_size(payload) > 64 do
    {:error, "Payload too long (max 64 characters)"}
  end
  defp validate_payload(payload), do: {:ok, payload}

  defp param_key_for("group"), do: "startgroup"
  defp param_key_for("channel"), do: "startchannel"
  defp param_key_for(_), do: "start"
end
