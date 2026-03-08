defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  HTTP client for Telegram Bot API.

  Handles authentication, request formatting, error handling,
  and response parsing for all Bot API methods.
  """

  alias Lux.Integrations.Telegram

  @retry_codes [429, 500, 502, 503, 504]
  @max_retries 3
  @retry_delay_ms 1000

  @doc """
  Make a request to the Telegram Bot API.

  ## Options
  - `:token` — Bot token (required)
  - `:plug` — Test plug for Req.Test
  """
  def request(method, params \\ %{}, opts \\ []) do
    token = opts[:token] || raise "Telegram bot token required"
    url = "#{Telegram.bot_url(token)}/#{method}"

    req_opts = [
      url: url,
      method: :post,
      json: params,
      retry: false
    ]

    req_opts = if opts[:plug], do: Keyword.put(req_opts, :plug, opts[:plug]), else: req_opts

    do_request(req_opts, 0)
  end

  @doc """
  Upload a file via multipart form.
  """
  def upload(method, file_field, file_path, params \\ %{}, opts \\ []) do
    token = opts[:token] || raise "Telegram bot token required"
    url = "#{Telegram.bot_url(token)}/#{method}"

    form_fields =
      params
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

    multipart =
      {:multipart,
       [{to_string(file_field), {:file, file_path}} | form_fields]}

    req_opts = [
      url: url,
      method: :post,
      body: multipart,
      retry: false
    ]

    req_opts = if opts[:plug], do: Keyword.put(req_opts, :plug, opts[:plug]), else: req_opts

    do_request(req_opts, 0)
  end

  defp do_request(req_opts, attempt) do
    case Req.request(req_opts) do
      {:ok, %{status: status, body: %{"ok" => true, "result" => result}}} when status in 200..299 ->
        {:ok, result}

      {:ok, %{status: 429, body: body}} when attempt < @max_retries ->
        retry_after = get_in(body, ["parameters", "retry_after"]) || 1
        Process.sleep(retry_after * 1000)
        do_request(req_opts, attempt + 1)

      {:ok, %{status: status}} when status in @retry_codes and attempt < @max_retries ->
        Process.sleep(@retry_delay_ms * (attempt + 1))
        do_request(req_opts, attempt + 1)

      {:ok, %{status: _status, body: %{"ok" => false, "description" => desc, "error_code" => code}}} ->
        {:error, %{code: code, description: desc}}

      {:ok, %{status: status, body: body}} ->
        {:error, %{code: status, description: inspect(body)}}

      {:error, reason} ->
        if attempt < @max_retries do
          Process.sleep(@retry_delay_ms * (attempt + 1))
          do_request(req_opts, attempt + 1)
        else
          {:error, %{code: 0, description: inspect(reason)}}
        end
    end
  end
end
