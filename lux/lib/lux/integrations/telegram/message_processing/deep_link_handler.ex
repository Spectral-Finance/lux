defmodule Lux.Integrations.Telegram.MessageProcessing.DeepLinkHandler do
  @moduledoc """
  Telegram deep linking handler.
  Decodes and encodes referral links, authentication tokens, and mini-app payloads,
  ensuring compliance with Telegram's 64-character payload limit.
  """

  @max_payload_length 64

  @doc """
  Parses a `/start` message or raw parameter string into structured deep link data.

  ## Examples
      iex> DeepLinkHandler.parse("ref_user123")
      {:ok, %{type: :referral, code: "user123", raw_payload: "ref_user123"}}

      iex> DeepLinkHandler.parse("/start auth_xyz789")
      {:ok, %{type: :auth, token: "xyz789", raw_payload: "auth_xyz789"}}
  """
  @spec parse(String.t()) :: {:ok, map()} | {:error, term()}
  def parse(nil), do: {:error, :empty_payload}
  def parse(""), do: {:error, :empty_payload}

  def parse(text) when is_binary(text) do
    payload = extract_payload(String.trim(text))

    cond do
      payload == "" ->
        {:error, :empty_payload}

      String.length(payload) > @max_payload_length ->
        {:error, {:payload_too_long, String.length(payload)}}

      true ->
        decode_payload(payload)
    end
  end

  @doc """
  Generates a deep link URL for a bot.

  ## Options:
    - `:type` - `:bot` (default `?start=`), `:group` (`?startgroup=`), or `:mini_app` (`?startapp=`)
    - `:app_name` - Mini app short name if type is `:mini_app`
    - `:domain` - Base domain (default `"t.me"`)
  """
  @spec generate_link(String.t(), String.t() | map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_link(bot_username, payload_or_map, opts \\ [])

  def generate_link(bot_username, payload, opts) when is_binary(payload) do
    clean_bot = String.replace_prefix(bot_username, "@", "")
    type = Keyword.get(opts, :type, :bot)
    domain = Keyword.get(opts, :domain, "https://t.me")

    if String.length(payload) > @max_payload_length do
      {:error, {:payload_exceeds_limit, String.length(payload)}}
    else
      url =
        case type do
          :bot ->
            "#{domain}/#{clean_bot}?start=#{payload}"

          :group ->
            "#{domain}/#{clean_bot}?startgroup=#{payload}"

          :mini_app ->
            app_name = Keyword.get(opts, :app_name, "app")
            "#{domain}/#{clean_bot}/#{app_name}?startapp=#{payload}"
        end

      {:ok, url}
    end
  end

  def generate_link(bot_username, map, opts) when is_map(map) do
    encoded = encode_map(map)
    generate_link(bot_username, encoded, opts)
  end

  # --- Internal Helpers ---

  defp extract_payload(text) do
    cond do
      String.starts_with?(text, "/start ") ->
        String.trim_leading(String.replace_prefix(text, "/start ", ""))

      String.starts_with?(text, "/startgroup ") ->
        String.trim_leading(String.replace_prefix(text, "/startgroup ", ""))

      String.starts_with?(text, "/start") ->
        ""

      true ->
        text
    end
  end

  defp decode_payload(payload) do
    cond do
      # Base64 prefixed (e.g. "b64_...")
      String.starts_with?(payload, "b64_") ->
        raw_b64 = String.replace_prefix(payload, "b64_", "")

        case Base.url_decode64(raw_b64, padding: false) do
          {:ok, decoded} ->
            {:ok, %{type: :base64, data: decoded, raw_payload: payload}}

          _ ->
            {:ok, %{type: :custom, raw_payload: payload}}
        end

      # Referral prefix: ref_XYZ
      String.starts_with?(payload, "ref_") ->
        ref_id = String.replace_prefix(payload, "ref_", "")
        {:ok, %{type: :referral, code: ref_id, raw_payload: payload}}

      # Auth token prefix: auth_XYZ
      String.starts_with?(payload, "auth_") ->
        token = String.replace_prefix(payload, "auth_", "")
        {:ok, %{type: :auth, token: token, raw_payload: payload}}

      # Transaction tracking: tx_XYZ
      String.starts_with?(payload, "tx_") ->
        tx = String.replace_prefix(payload, "tx_", "")
        {:ok, %{type: :transaction, hash: tx, raw_payload: payload}}

      # Campaign tracking: c_XYZ or campaign_XYZ
      String.starts_with?(payload, "campaign_") ->
        cid = String.replace_prefix(payload, "campaign_", "")
        {:ok, %{type: :campaign, id: cid, raw_payload: payload}}

      # Key-value pairs: k1_v1__k2_v2
      String.contains?(payload, "__") ->
        pairs =
          payload
          |> String.split("__")
          |> Enum.reduce(%{}, fn pair, acc ->
            case String.split(pair, "_", parts: 2) do
              [k, v] -> Map.put(acc, String.to_atom(k), v)
              [k] -> Map.put(acc, String.to_atom(k), true)
            end
          end)

        {:ok, %{type: :key_value, pairs: pairs, raw_payload: payload}}

      true ->
        {:ok, %{type: :custom, raw_payload: payload}}
    end
  end

  defp encode_map(map) do
    map
    |> Enum.map(fn {k, v} -> "#{k}_#{v}" end)
    |> Enum.join("__")
  end
end
