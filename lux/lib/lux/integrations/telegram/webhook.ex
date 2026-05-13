defmodule Lux.Integrations.Telegram.Webhook do
  @moduledoc """
  Helpers for validating and parsing Telegram webhook updates.

  Telegram sends the optional secret token in the
  `X-Telegram-Bot-Api-Secret-Token` header. Verifying that header before
  processing the JSON body prevents unrelated traffic from being accepted as a
  bot update.
  """

  @secret_token_header "x-telegram-bot-api-secret-token"

  @type update_type ::
          :message
          | :edited_message
          | :callback_query
          | :inline_query
          | :chosen_inline_result
          | :unknown

  @doc """
  Verifies a webhook secret token from request headers.
  """
  @spec valid_secret_token?(term(), String.t()) :: boolean()
  def valid_secret_token?(headers, expected_secret)
      when is_binary(expected_secret) and byte_size(expected_secret) > 0 do
    with token when is_binary(token) <- header(headers, @secret_token_header),
         true <- byte_size(token) == byte_size(expected_secret) do
      Plug.Crypto.secure_compare(token, expected_secret)
    else
      _ -> false
    end
  end

  def valid_secret_token?(_headers, _expected_secret), do: false

  @doc """
  Parses a webhook update from decoded JSON or a JSON string.
  """
  @spec parse_update(map() | binary()) :: {:ok, map()} | {:error, term()}
  def parse_update(%{} = update), do: {:ok, update}

  def parse_update(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{} = update} -> {:ok, update}
      {:ok, _other} -> {:error, :invalid_update}
      {:error, error} -> {:error, error}
    end
  end

  def parse_update(_body), do: {:error, :invalid_update}

  @doc """
  Classifies a Telegram update into the primary update type Lux should route.
  """
  @spec classify_update(map()) :: update_type()
  def classify_update(%{"message" => _message}), do: :message
  def classify_update(%{"edited_message" => _message}), do: :edited_message
  def classify_update(%{"callback_query" => _query}), do: :callback_query
  def classify_update(%{"inline_query" => _query}), do: :inline_query
  def classify_update(%{"chosen_inline_result" => _result}), do: :chosen_inline_result
  def classify_update(_update), do: :unknown

  defp header(headers, name) when is_map(headers) do
    headers
    |> Map.to_list()
    |> header(name)
  end

  defp header(headers, name) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) == name, do: value

      _ ->
        nil
    end)
  end

  defp header(_headers, _name), do: nil
end
