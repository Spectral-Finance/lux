defmodule Lux.Prisms.Telegram.DeepLinkHandler do
  @moduledoc """
  Handles Telegram deep linking (`t.me/botname?start=payload`).

  Supports:
  - Decoding base64 payloads
  - Structured payloads (action_param1_param2)
  - Referral tracking
  - Group deep links (`startgroup` parameter)
  """

  use Lux.Prism,
    name: "Telegram Deep Link Handler",
    description: "Parse and handle Telegram deep link payloads",
    input_schema: %{
      type: :object,
      properties: %{
        payload: %{type: :string, description: "Raw deep link payload from /start command"},
        type: %{type: :string, enum: ["start", "startgroup"], description: "Deep link type"}
      },
      required: ["payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        decoded: %{type: :string},
        action: %{type: :string},
        params: %{type: :object}
      }
    }

  @impl true
  def handler(params, _agent) do
    payload = params["payload"] || params[:payload] || ""
    type = params["type"] || params[:type] || "start"

    decoded = decode_payload(payload)
    parsed = parse_payload(decoded)

    {:ok, %{
      raw: payload,
      decoded: decoded,
      type: type,
      action: parsed.action,
      params: parsed.params,
      is_referral: parsed.action == "ref",
      referral_code: if(parsed.action == "ref", do: Map.get(parsed.params, "code"), else: nil)
    }}
  end

  @doc "Decode a deep link payload (try base64 first, then plain)."
  def decode_payload(payload) do
    case Base.url_decode64(payload, padding: false) do
      {:ok, decoded} -> decoded
      :error -> payload
    end
  end

  @doc """
  Parse decoded payload into action and params.

  Format: `action_param1_param2` or `action-key1-val1-key2-val2`
  """
  def parse_payload(decoded) do
    parts = String.split(decoded, "_", parts: 2)

    case parts do
      [action, rest] ->
        params = parse_deep_link_params(rest)
        %{action: action, params: params}

      [action] ->
        %{action: action, params: %{}}
    end
  end

  defp parse_deep_link_params(str) do
    # Try key-value pairs first (key1-val1-key2-val2)
    parts = String.split(str, "-")

    if rem(length(parts), 2) == 0 && length(parts) >= 2 do
      parts
      |> Enum.chunk_every(2)
      |> Enum.reduce(%{}, fn [k, v], acc -> Map.put(acc, k, v) end)
    else
      %{"value" => str}
    end
  end
end
