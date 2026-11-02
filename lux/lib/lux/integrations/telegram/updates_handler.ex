defmodule Lux.Integrations.Telegram.UpdatesHandler do
  @moduledoc """
  Webhook update handling and payload normalization for Telegram Bot API.
  Verifies webhook secret tokens (`X-Telegram-Bot-Api-Secret-Token`),
  normalizes incoming update payloads, and provides long-polling helpers.
  """

  alias Lux.Integrations.Telegram.Client

  @doc """
  Verifies the Telegram webhook secret token using constant-time comparison.
  """
  @spec verify_secret_token(String.t() | nil, String.t() | nil) :: boolean()
  def verify_secret_token(header_value, expected_secret)
      when is_binary(header_value) and is_binary(expected_secret) and header_value != "" do
    byte_size(header_value) == byte_size(expected_secret) and
      :crypto.hash(:sha256, header_value) == :crypto.hash(:sha256, expected_secret)
  end

  def verify_secret_token(_header, _expected), do: false

  @doc """
  Normalizes a raw Telegram Update map into a structured event map.
  """
  @spec normalize_update(map()) :: map()
  def normalize_update(%{"update_id" => update_id} = raw) do
    cond do
      msg = raw["message"] ->
        %{
          update_id: update_id,
          type: :message,
          message_id: msg["message_id"],
          chat_id: get_in(msg, ["chat", "id"]),
          chat_type: get_in(msg, ["chat", "type"]),
          from_id: get_in(msg, ["from", "id"]),
          from_username: get_in(msg, ["from", "username"]),
          text: msg["text"],
          entities: msg["entities"] || [],
          raw: raw
        }

      cb = raw["callback_query"] ->
        %{
          update_id: update_id,
          type: :callback_query,
          query_id: cb["id"],
          chat_id: get_in(cb, ["message", "chat", "id"]),
          message_id: get_in(cb, ["message", "message_id"]),
          from_id: get_in(cb, ["from", "id"]),
          data: cb["data"],
          raw: raw
        }

      iq = raw["inline_query"] ->
        %{
          update_id: update_id,
          type: :inline_query,
          query_id: iq["id"],
          from_id: get_in(iq, ["from", "id"]),
          query: iq["query"],
          offset: iq["offset"],
          raw: raw
        }

      cp = raw["channel_post"] ->
        %{
          update_id: update_id,
          type: :channel_post,
          message_id: cp["message_id"],
          chat_id: get_in(cp, ["chat", "id"]),
          text: cp["text"],
          raw: raw
        }

      true ->
        %{
          update_id: update_id,
          type: :unknown,
          raw: raw
        }
    end
  end

  def normalize_update(other), do: %{type: :invalid, raw: other}

  @doc """
  Polls for updates using the `/getUpdates` endpoint.
  """
  @spec poll_updates(keyword() | map(), map()) :: {:ok, list(map())} | {:error, term()}
  def poll_updates(params \\ %{}, opts \\ %{}) do
    query_params =
      params
      |> Enum.into(%{})
      |> Map.take([:offset, :limit, :timeout, :allowed_updates, "offset", "limit", "timeout", "allowed_updates"])

    req_opts =
      opts
      |> Map.put(:params, query_params)

    case Client.request(:get, "/getUpdates", req_opts) do
      {:ok, %{"result" => updates}} when is_list(updates) ->
        normalized = Enum.map(updates, &normalize_update/1)
        {:ok, normalized}

      {:ok, other} ->
        {:ok, other}

      error ->
        error
    end
  end
end
