defmodule Lux.Telegram.Media do
  @moduledoc """
  Media API functions for Telegram Bot API integration.
  """

  alias Lux.Telegram.Client
  alias Lux.Telegram.Keyboards

  @doc """
  Sends a photo to a Telegram chat.
  Supports photo as `file_id` string, HTTP URL string, or `{:file, path}`.
  """
  def send_photo(chat_id, photo, opts \\ %{}) do
    send_media(chat_id, :photo, photo, "/sendPhoto", opts)
  end

  @doc """
  Sends a document to a Telegram chat.
  Supports document as `file_id` string, HTTP URL string, or `{:file, path}`.
  """
  def send_document(chat_id, document, opts \\ %{}) do
    send_media(chat_id, :document, document, "/sendDocument", opts)
  end

  @doc """
  Sends a voice audio to a Telegram chat.
  Supports voice as `file_id` string, HTTP URL string, or `{:file, path}`.
  """
  def send_voice(chat_id, voice, opts \\ %{}) do
    send_media(chat_id, :voice, voice, "/sendVoice", opts)
  end

  @doc """
  Sends an audio file to a Telegram chat.
  Supports audio as `file_id` string, HTTP URL string, or `{:file, path}`.
  """
  def send_audio(chat_id, audio, opts \\ %{}) do
    send_media(chat_id, :audio, audio, "/sendAudio", opts)
  end

  @doc """
  Sends a video file to a Telegram chat.
  Supports video as `file_id` string, HTTP URL string, or `{:file, path}`.
  """
  def send_video(chat_id, video, opts \\ %{}) do
    send_media(chat_id, :video, video, "/sendVideo", opts)
  end

  @doc """
  Gets file info for a Telegram file_id.
  """
  def get_file(file_id, opts \\ %{}) do
    {client_opts, api_opts} = split_opts(opts)
    json = Map.merge(api_opts, %{file_id: file_id})
    Client.request(:post, "/getFile", Map.put(client_opts, :json, json))
  end

  @doc """
  Downloads a Telegram file by file_path or file_id.
  If given a file_id (no slashes or dots), it calls get_file first to resolve file_path.
  """
  def download_file(file_path_or_id, opts \\ %{}) do
    with {:ok, file_path} <- resolve_file_path(file_path_or_id, opts) do
      opts_list = if is_list(opts), do: opts, else: Map.to_list(opts)
      opts_map = Map.new(opts_list)

      token = Lux.Integrations.Telegram.fetch_token(opts)
      url = "https://api.telegram.org/file/bot#{token}/#{file_path}"

      non_req_keys = [
        :token,
        :base_url,
        :req_options,
        :sleep_fun,
        :max_retries,
        :max_rate_limit_retries,
        :base_backoff,
        :max_backoff,
        :backoff_factor
      ]

      config_opts =
        Application.get_env(:lux, :req_options, [])
        |> Keyword.merge(Application.get_env(:lux, Lux.Telegram.Client, []))
        |> Keyword.merge(Application.get_env(:lux, Lux.Integrations.Telegram.Client, []))

      client_req_opts = Keyword.drop(opts_map[:req_options] || [], non_req_keys)

      req_opts =
        [method: :get, url: url, retry: false]
        |> Keyword.merge(Keyword.drop(config_opts, non_req_keys))
        |> Keyword.merge(client_req_opts)
        |> Keyword.merge(Keyword.drop(opts_list, non_req_keys))
        |> maybe_add_plug(opts_map[:plug])

      middleware_opts =
        config_opts
        |> Keyword.merge(opts_list)

      try do
        req_opts
        |> Req.new()
        |> Lux.Telegram.Middleware.RateLimit.attach(middleware_opts)
        |> Lux.Telegram.Middleware.Retry.attach(middleware_opts)
        |> Req.request()
        |> case do
          {:ok, %{status: status, body: body}} when status in 200..299 ->
            {:ok, body}

          {:ok, %{status: 401}} ->
            {:error, :invalid_token}

          {:ok, %{status: 429, body: %{"parameters" => %{"retry_after" => _}} = body}} ->
            {:error, {429, body}}

          {:ok, %{status: 429, body: %{parameters: %{retry_after: _}} = body}} ->
            {:error, {429, body}}

          {:ok, %{status: status, body: %{"description" => message}}} ->
            {:error, {status, message}}

          {:ok, %{status: status, body: body}} ->
            {:error, {status, body}}

          {:error, error} ->
            {:error, error}
        end
      rescue
        e -> {:error, e}
      end
    end
  end

  defp resolve_file_path(file_path_or_id, opts) do
    if String.contains?(file_path_or_id, "/") or String.contains?(file_path_or_id, ".") do
      {:ok, file_path_or_id}
    else
      case get_file(file_path_or_id, opts) do
        {:ok, %{"result" => %{"file_path" => path}}} when is_binary(path) ->
          {:ok, path}

        {:ok, %{result: %{file_path: path}}} when is_binary(path) ->
          {:ok, path}

        {:ok, %{"result" => %{file_path: path}}} when is_binary(path) ->
          {:ok, path}

        {:ok, %{result: %{"file_path" => path}}} when is_binary(path) ->
          {:ok, path}

        {:ok, other} ->
          {:error, {:unexpected_response, other}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp maybe_add_plug(req_opts, nil), do: req_opts
  defp maybe_add_plug(req_opts, plug), do: Keyword.put(req_opts, :plug, plug)

  defp send_media(chat_id, param_name, media_arg, endpoint_path, opts) do
    {client_opts, api_opts} = split_opts(opts)
    api_opts = normalize_api_opts(api_opts)

    case media_arg do
      {:file, file_path} ->
        file_part = {File.stream!(file_path), filename: Path.basename(file_path)}

        form_data =
          api_opts
          |> Enum.map(fn
            {k, v} when is_map(v) or is_list(v) -> {k, Jason.encode!(v)}
            {k, v} -> {k, v}
          end)
          |> Map.new()
          |> Map.put(:chat_id, chat_id)
          |> Map.put(param_name, file_part)

        Client.request(:post, endpoint_path, Map.put(client_opts, :form, form_data))

      _ ->
        json =
          api_opts
          |> Map.put(:chat_id, chat_id)
          |> Map.put(param_name, media_arg)

        Client.request(:post, endpoint_path, Map.put(client_opts, :json, json))
    end
  end

  defp split_opts(opts) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}

    {client_opts, api_opts} =
      Map.split(opts_map, [
        :token,
        :plug,
        :headers,
        :base_url,
        :req_options,
        :sleep_fun,
        :max_retries,
        :max_rate_limit_retries,
        :base_backoff,
        :max_backoff,
        :backoff_factor
      ])

    {client_opts, api_opts}
  end

  defp normalize_api_opts(api_opts) do
    if Map.has_key?(api_opts, :reply_markup) do
      Map.update!(api_opts, :reply_markup, &Keyboards.to_map/1)
    else
      api_opts
    end
  end
end
