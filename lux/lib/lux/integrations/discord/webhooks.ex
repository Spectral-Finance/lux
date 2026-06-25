defmodule Lux.Integrations.Discord.Webhooks do
  @moduledoc """
  Discord webhook API helpers.
  """

  alias Lux.Integrations.Discord.Client

  @type request_opts :: keyword() | map()

  @doc """
  Creates a webhook in a Discord channel.
  """
  @spec create(String.t(), map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def create(channel_id, attrs, opts \\ %{}) do
    request_with_retry(:post, "/channels/#{channel_id}/webhooks", attrs, opts)
  end

  @doc """
  Updates a webhook by ID.
  """
  @spec update(String.t(), map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def update(webhook_id, attrs, opts \\ %{}) do
    request_with_retry(:patch, "/webhooks/#{webhook_id}", attrs, opts)
  end

  @doc """
  Deletes a webhook by ID.
  """
  @spec delete(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def delete(webhook_id, opts \\ %{}) do
    request_with_retry(:delete, "/webhooks/#{webhook_id}", nil, opts)
  end

  @doc """
  Executes a webhook using its token.
  """
  @spec execute(String.t(), String.t(), map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def execute(webhook_id, token, payload, opts \\ %{}) do
    wait = if truthy?(get_opt(opts, :wait, true)), do: "true", else: "false"
    request_with_retry(:post, "/webhooks/#{webhook_id}/#{token}?wait=#{wait}", payload, opts)
  end

  defp request_with_retry(method, path, json, opts) do
    retries = get_opt(opts, :retries, 2)
    retry_delay_ms = get_opt(opts, :retry_delay_ms, 250)
    request_opts = opts |> Map.new() |> Map.drop([:retries, :retry_delay_ms, :wait])
    request_opts = if is_nil(json), do: request_opts, else: Map.put(request_opts, :json, json)

    do_request(method, path, request_opts, retries, retry_delay_ms)
  end

  defp do_request(method, path, opts, retries, retry_delay_ms) do
    case Client.request(method, path, opts) do
      {:error, {429, _message}} when retries > 0 ->
        Process.sleep(retry_delay_ms)
        do_request(method, path, opts, retries - 1, retry_delay_ms)

      result ->
        result
    end
  end

  defp get_opt(opts, key, default) when is_map(opts), do: Map.get(opts, key, default)
  defp get_opt(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)

  defp truthy?(value), do: value in [true, "true", "1", 1]
end
