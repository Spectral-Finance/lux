defmodule Lux.Telegram.Client do
  @moduledoc """
  Client module for Telegram Bot API integration.
  Provides authentication token management, HTTP request dispatching with Req,
  and high-level bot management helpers.
  """

  require Logger
  alias Lux.Telegram.Types

  defstruct token: nil, base_url: "https://api.telegram.org/bot", req_options: []

  @type t :: %__MODULE__{
          token: String.t() | nil,
          base_url: String.t(),
          req_options: keyword()
        }

  @doc """
  Creates a new Telegram Client struct.

  Token resolution order:
  1. Provided `:token` parameter or struct field
  2. Application config (`Application.get_env(:lux, :telegram_bot_token)`)
  3. System environment (`System.get_env("TELEGRAM_BOT_TOKEN")`)
  """
  @spec new(String.t() | keyword() | map() | nil, keyword() | map()) :: t()
  def new(token_or_opts \\ nil, opts \\ [])

  def new(token, opts) when is_binary(token) do
    opts_list = normalize_opts(opts)
    base_url = Keyword.get(opts_list, :base_url, "https://api.telegram.org/bot")
    req_options = Keyword.get(opts_list, :req_options, [])

    %__MODULE__{
      token: token,
      base_url: base_url,
      req_options: req_options
    }
  end

  def new(opts, _) when is_list(opts) or is_map(opts) do
    opts_list = normalize_opts(opts)
    token = Keyword.get(opts_list, :token) || resolve_token(nil)
    base_url = Keyword.get(opts_list, :base_url, "https://api.telegram.org/bot")
    req_options = Keyword.get(opts_list, :req_options, [])

    %__MODULE__{
      token: token,
      base_url: base_url,
      req_options: req_options
    }
  end

  def new(nil, _) do
    %__MODULE__{
      token: resolve_token(nil),
      base_url: "https://api.telegram.org/bot",
      req_options: []
    }
  end

  @doc """
  Resolves Telegram bot token from given options, struct, application config, or system ENV.
  """
  @spec resolve_token(term()) :: String.t() | nil
  def resolve_token(token_or_opts) do
    cond do
      is_binary(token_or_opts) and token_or_opts != "" ->
        token_or_opts

      is_map(token_or_opts) and is_binary(Map.get(token_or_opts, :token)) ->
        Map.get(token_or_opts, :token)

      is_list(token_or_opts) and is_binary(Keyword.get(token_or_opts, :token)) ->
        Keyword.get(token_or_opts, :token)

      true ->
        fallback_token()
    end
  end

  defp fallback_token do
    token =
      try do
        Lux.Config.telegram_bot_token()
      rescue
        _ -> nil
      catch
        _ -> nil
      end

    token || Application.get_env(:lux, :telegram_bot_token) || System.get_env("TELEGRAM_BOT_TOKEN")
  end

  @doc """
  Dispatches an HTTP request to Telegram Bot API endpoint with explicit client and options.
  """
  def request(%__MODULE__{} = client, method, endpoint, opts) do
    do_request(client, method, endpoint, opts)
  end

  def request(client_opts, method, endpoint, opts) when is_map(client_opts) or is_list(client_opts) do
    c = new(client_opts)
    do_request(c, method, endpoint, opts)
  end

  @doc """
  Dispatches an HTTP request to Telegram Bot API endpoint.
  Supports:
  - `request(client, method, endpoint)`
  - `request(method, endpoint, opts)`
  """
  def request(%__MODULE__{} = client, method, endpoint) do
    do_request(client, method, endpoint, [])
  end

  def request(method, endpoint, opts) when is_atom(method) or is_binary(method) do
    c = new(opts)
    do_request(c, method, endpoint, opts)
  end

  @doc """
  Dispatches an HTTP request to Telegram Bot API endpoint with default client.
  """
  def request(method, endpoint) when is_atom(method) or is_binary(method) do
    request(method, endpoint, [])
  end

  defp do_request(%__MODULE__{} = client, method, endpoint, opts) do
    opts_list = normalize_opts(opts)
    opts_map = Map.new(opts_list)

    token = opts_map[:token] || client.token || resolve_token(nil)
    url = build_url(client.base_url, token, endpoint)
    method_atom = method |> to_string() |> String.downcase() |> String.to_existing_atom()

    payload_params = extract_payload(opts_list, method_atom)

    initial_headers =
      case payload_params do
        {:form, _} -> []
        {:form_multipart, _} -> []
        _ -> [{"Content-Type", "application/json"}]
      end

    middleware_keys = [
      :sleep_fun,
      :max_retries,
      :max_rate_limit_retries,
      :base_backoff,
      :max_backoff,
      :backoff_factor
    ]

    client_req_opts = Keyword.drop(client.req_options, middleware_keys)
    app_env_client_opts = Keyword.drop(Application.get_env(:lux, Lux.Telegram.Client, []), middleware_keys)
    app_env_integ_opts = Keyword.drop(Application.get_env(:lux, Lux.Integrations.Telegram.Client, []), middleware_keys)

    req_opts =
      [
        method: method_atom,
        url: url,
        headers: initial_headers,
        retry: false
      ]
      |> Keyword.merge(app_env_client_opts)
      |> Keyword.merge(app_env_integ_opts)
      |> Keyword.merge(client_req_opts)
      |> apply_payload(method_atom, payload_params)
      |> maybe_remove_json_content_type(payload_params)
      |> maybe_add_plug(opts_map[:plug])

    middleware_opts =
      Application.get_env(:lux, Lux.Telegram.Client, [])
      |> Keyword.merge(Application.get_env(:lux, Lux.Integrations.Telegram.Client, []))
      |> Keyword.merge(client.req_options)
      |> Keyword.merge(opts_list)

    try do
      req_opts
      |> Req.new()
      |> Lux.Telegram.Middleware.RateLimit.attach(middleware_opts)
      |> Lux.Telegram.Middleware.Retry.attach(middleware_opts)
      |> Req.request()
      |> parse_response()
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Interpolates bot token into the base URL and endpoint.
  """
  def build_url(base_url, token, endpoint) do
    base_url = if is_binary(base_url) and base_url != "", do: base_url, else: "https://api.telegram.org/bot"
    token = token || ""
    endpoint = endpoint || ""

    base = String.trim_trailing(base_url, "/")
    ep = "/" <> String.trim_leading(endpoint, "/")

    cond do
      String.contains?(base, "{token}") ->
        String.replace(base, "{token}", token) <> ep

      String.ends_with?(base, "/bot") ->
        base <> token <> ep

      String.contains?(base, "/bot") ->
        base <> ep

      true ->
        base <> "/bot" <> token <> ep
    end
  end

  defp parse_response({:ok, %{status: status} = response}) when status in 200..299 do
    case response.body do
      %{"ok" => true} = body ->
        {:ok, body}

      %{"ok" => false} = body ->
        {:error, body}

      body ->
        {:ok, body}
    end
  end

  defp parse_response({:ok, %{status: 401}}) do
    {:error, :invalid_token}
  end

  defp parse_response({:ok, %{status: 429, body: %{"parameters" => %{"retry_after" => _}} = body}}) do
    {:error, {429, body}}
  end

  defp parse_response({:ok, %{status: 429, body: %{parameters: %{retry_after: _}} = body}}) do
    {:error, {429, body}}
  end

  defp parse_response({:ok, %{status: status, body: %{"description" => message}}}) do
    {:error, {status, message}}
  end

  defp parse_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp parse_response({:error, error}) do
    {:error, error}
  end

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(_), do: []

  defp extract_payload(opts_list, _method) do
    opts_map = Map.new(opts_list)

    cond do
      Map.has_key?(opts_map, :form) ->
        {:form, opts_map[:form]}

      Map.has_key?(opts_map, :form_multipart) ->
        {:form_multipart, opts_map[:form_multipart]}

      Map.has_key?(opts_map, :json) ->
        {:json, opts_map[:json]}

      Map.has_key?(opts_map, :body) ->
        {:body, opts_map[:body]}

      Map.has_key?(opts_map, :params) ->
        {:params, opts_map[:params]}

      true ->
        clean =
          Keyword.drop(opts_list, [
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

        clean_map = Map.new(clean)

        if has_form_or_file_data?(clean_map) do
          {:form, clean_map}
        else
          {:clean, clean_map}
        end
    end
  end

  defp apply_payload(req_opts, _method, {:form, form}) do
    Keyword.put(req_opts, :form_multipart, normalize_form_data(form))
  end

  defp apply_payload(req_opts, _method, {:form_multipart, form_mp}) do
    Keyword.put(req_opts, :form_multipart, normalize_form_data(form_mp))
  end

  defp apply_payload(req_opts, _method, {:json, json}), do: Keyword.put(req_opts, :json, json)
  defp apply_payload(req_opts, _method, {:body, body}), do: Keyword.put(req_opts, :body, body)
  defp apply_payload(req_opts, _method, {:params, params}), do: Keyword.put(req_opts, :params, params)

  defp apply_payload(req_opts, :get, {:clean, params}) when map_size(params) > 0 do
    Keyword.put(req_opts, :params, params)
  end

  defp apply_payload(req_opts, _method, {:clean, params}) when map_size(params) > 0 do
    Keyword.put(req_opts, :json, params)
  end

  defp apply_payload(req_opts, _method, _), do: req_opts

  defp maybe_remove_json_content_type(req_opts, payload_params) do
    is_form =
      match?({:form, _}, payload_params) or
        match?({:form_multipart, _}, payload_params) or
        Keyword.has_key?(req_opts, :form) or
        Keyword.has_key?(req_opts, :form_multipart)

    if is_form do
      headers = Keyword.get(req_opts, :headers, [])

      filtered =
        Enum.reject(headers, fn {k, v} ->
          String.downcase(to_string(k)) == "content-type" and String.downcase(to_string(v)) == "application/json"
        end)

      if filtered == [] do
        Keyword.delete(req_opts, :headers)
      else
        Keyword.put(req_opts, :headers, filtered)
      end
    else
      req_opts
    end
  end

  defp has_form_or_file_data?(map) when is_map(map) do
    Enum.any?(map, fn {_k, v} -> is_form_or_file_value?(v) end)
  end

  defp has_form_or_file_data?(_), do: false

  defp is_form_or_file_value?({:file, _path}), do: true
  defp is_form_or_file_value?(%File.Stream{}), do: true
  defp is_form_or_file_value?({%File.Stream{}, _opts}), do: true
  defp is_form_or_file_value?({stream, opts}) when is_list(opts) and is_struct(stream, File.Stream), do: true
  defp is_form_or_file_value?({_data, opts}) when is_list(opts), do: true
  defp is_form_or_file_value?(_), do: false

  defp normalize_form_data(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {k, normalize_form_value(v)} end)
  end

  defp normalize_form_data(list) when is_list(list) do
    Enum.map(list, fn {k, v} -> {k, normalize_form_value(v)} end)
  end

  defp normalize_form_data(other), do: other

  defp normalize_form_value({:file, path}) when is_binary(path) do
    {File.stream!(path), filename: Path.basename(path)}
  end

  defp normalize_form_value(v), do: v

  defp maybe_add_plug(req_opts, nil), do: req_opts
  defp maybe_add_plug(req_opts, plug), do: Keyword.put(req_opts, :plug, plug)

  # Bot Management Helpers

  @doc """
  Returns basic information about the bot in form of a `User` struct.
  """
  @spec get_me(t() | keyword() | map()) :: {:ok, Types.User.t() | map()} | {:error, term()}
  def get_me(client_or_opts \\ %{}) do
    {client, opts} = extract_client_and_opts(client_or_opts)

    case request(client, :get, "/getMe", opts) do
      {:ok, %{"result" => result}} -> {:ok, Types.User.from_map(result)}
      {:ok, res} -> {:ok, res}
      error -> error
    end
  end

  @doc """
  Logs out from the cloud Bot API server.
  """
  @spec log_out(t() | keyword() | map()) :: {:ok, map() | boolean()} | {:error, term()}
  def log_out(client_or_opts \\ %{}) do
    {client, opts} = extract_client_and_opts(client_or_opts)
    request(client, :post, "/logOut", opts)
  end

  @doc """
  Closes the bot instance before moving it to another server.
  """
  @spec close(t() | keyword() | map()) :: {:ok, map() | boolean()} | {:error, term()}
  def close(client_or_opts \\ %{}) do
    {client, opts} = extract_client_and_opts(client_or_opts)
    request(client, :post, "/close", opts)
  end

  @doc """
  Specifies a URL and receives incoming updates via an outgoing webhook.
  """
  @spec set_webhook(t() | String.t(), String.t() | keyword() | map(), keyword() | map()) ::
          {:ok, map()} | {:error, term()}
  def set_webhook(client_or_url, url_or_opts \\ [], opts \\ [])

  def set_webhook(%__MODULE__{} = client, url, opts) when is_binary(url) do
    opts_list = normalize_opts(opts)
    {client_opts, body_opts} = Keyword.split(opts_list, [:token, :base_url, :req_options, :plug])
    payload = Map.merge(%{url: url}, Map.new(body_opts))
    request(client, :post, "/setWebhook", Keyword.merge(client_opts, [json: payload]))
  end

  def set_webhook(url, opts, extra_opts)
      when is_binary(url) and (is_list(extra_opts) or is_map(extra_opts)) and extra_opts != [] and
             extra_opts != %{} do
    client = new(extra_opts)
    set_webhook(client, url, opts)
  end

  def set_webhook(url, opts, _) when is_binary(url) do
    client = new(opts)
    set_webhook(client, url, opts)
  end


  @doc """
  Removes webhook integration.
  """
  @spec delete_webhook(t() | keyword() | map(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def delete_webhook(client_or_opts \\ %{}, opts \\ [])

  def delete_webhook(%__MODULE__{} = client, opts) do
    request(client, :post, "/deleteWebhook", opts)
  end

  def delete_webhook(opts, extra) when is_list(opts) or is_map(opts) do
    opts_list = normalize_opts(opts)
    extra_list = normalize_opts(extra)
    merged_opts = Keyword.merge(opts_list, extra_list)

    if Keyword.has_key?(merged_opts, :token) or Keyword.has_key?(merged_opts, :base_url) or Keyword.has_key?(merged_opts, :plug) do
      client = new(merged_opts)
      request(client, :post, "/deleteWebhook", merged_opts)
    else
      client = new()
      request(client, :post, "/deleteWebhook", merged_opts)
    end
  end


  @doc """
  Gets current webhook status.
  """
  @spec get_webhook_info(t() | keyword() | map()) :: {:ok, Types.WebhookInfo.t() | map()} | {:error, term()}
  def get_webhook_info(client_or_opts \\ %{}) do
    {client, opts} = extract_client_and_opts(client_or_opts)

    case request(client, :get, "/getWebhookInfo", opts) do
      {:ok, %{"result" => result}} -> {:ok, Types.WebhookInfo.from_map(result)}
      {:ok, res} -> {:ok, res}
      error -> error
    end
  end

  # Messaging API Helpers
  def send_message(%__MODULE__{} = client, chat_id, text, opts) do
    Lux.Telegram.Messaging.send_message(chat_id, text, merge_client_opts(client, opts))
  end

  def send_message(%__MODULE__{} = client, chat_id, text) do
    Lux.Telegram.Messaging.send_message(chat_id, text, merge_client_opts(client, %{}))
  end

  def send_message(chat_id, text, opts) do
    Lux.Telegram.Messaging.send_message(chat_id, text, opts)
  end

  defdelegate send_message(chat_id, text), to: Lux.Telegram.Messaging

  def edit_message_text(%__MODULE__{} = client, chat_id, message_id, text, opts) do
    Lux.Telegram.Messaging.edit_message_text(chat_id, message_id, text, merge_client_opts(client, opts))
  end

  def edit_message_text(%__MODULE__{} = client, chat_id, message_id, text) do
    Lux.Telegram.Messaging.edit_message_text(chat_id, message_id, text, merge_client_opts(client, %{}))
  end

  def edit_message_text(chat_id, message_id, text, opts) do
    Lux.Telegram.Messaging.edit_message_text(chat_id, message_id, text, opts)
  end

  defdelegate edit_message_text(chat_id, message_id, text), to: Lux.Telegram.Messaging

  def delete_message(%__MODULE__{} = client, chat_id, message_id, opts) do
    Lux.Telegram.Messaging.delete_message(chat_id, message_id, merge_client_opts(client, opts))
  end

  def delete_message(%__MODULE__{} = client, chat_id, message_id) do
    Lux.Telegram.Messaging.delete_message(chat_id, message_id, merge_client_opts(client, %{}))
  end

  def delete_message(chat_id, message_id, opts) do
    Lux.Telegram.Messaging.delete_message(chat_id, message_id, opts)
  end

  defdelegate delete_message(chat_id, message_id), to: Lux.Telegram.Messaging

  def copy_message(%__MODULE__{} = client, chat_id, from_chat_id, message_id, opts) do
    Lux.Telegram.Messaging.copy_message(chat_id, from_chat_id, message_id, merge_client_opts(client, opts))
  end

  def copy_message(%__MODULE__{} = client, chat_id, from_chat_id, message_id) do
    Lux.Telegram.Messaging.copy_message(chat_id, from_chat_id, message_id, merge_client_opts(client, %{}))
  end

  def copy_message(chat_id, from_chat_id, message_id, opts) do
    Lux.Telegram.Messaging.copy_message(chat_id, from_chat_id, message_id, opts)
  end

  defdelegate copy_message(chat_id, from_chat_id, message_id), to: Lux.Telegram.Messaging

  def forward_message(%__MODULE__{} = client, chat_id, from_chat_id, message_id, opts) do
    Lux.Telegram.Messaging.forward_message(chat_id, from_chat_id, message_id, merge_client_opts(client, opts))
  end

  def forward_message(%__MODULE__{} = client, chat_id, from_chat_id, message_id) do
    Lux.Telegram.Messaging.forward_message(chat_id, from_chat_id, message_id, merge_client_opts(client, %{}))
  end

  def forward_message(chat_id, from_chat_id, message_id, opts) do
    Lux.Telegram.Messaging.forward_message(chat_id, from_chat_id, message_id, opts)
  end

  defdelegate forward_message(chat_id, from_chat_id, message_id), to: Lux.Telegram.Messaging

  # Media API Helpers
  def send_photo(%__MODULE__{} = client, chat_id, photo, opts) do
    Lux.Telegram.Media.send_photo(chat_id, photo, merge_client_opts(client, opts))
  end

  def send_photo(%__MODULE__{} = client, chat_id, photo) do
    Lux.Telegram.Media.send_photo(chat_id, photo, merge_client_opts(client, %{}))
  end

  def send_photo(chat_id, photo, opts) do
    Lux.Telegram.Media.send_photo(chat_id, photo, opts)
  end

  defdelegate send_photo(chat_id, photo), to: Lux.Telegram.Media

  def send_document(%__MODULE__{} = client, chat_id, document, opts) do
    Lux.Telegram.Media.send_document(chat_id, document, merge_client_opts(client, opts))
  end

  def send_document(%__MODULE__{} = client, chat_id, document) do
    Lux.Telegram.Media.send_document(chat_id, document, merge_client_opts(client, %{}))
  end

  def send_document(chat_id, document, opts) do
    Lux.Telegram.Media.send_document(chat_id, document, opts)
  end

  defdelegate send_document(chat_id, document), to: Lux.Telegram.Media

  def send_voice(%__MODULE__{} = client, chat_id, voice, opts) do
    Lux.Telegram.Media.send_voice(chat_id, voice, merge_client_opts(client, opts))
  end

  def send_voice(%__MODULE__{} = client, chat_id, voice) do
    Lux.Telegram.Media.send_voice(chat_id, voice, merge_client_opts(client, %{}))
  end

  def send_voice(chat_id, voice, opts) do
    Lux.Telegram.Media.send_voice(chat_id, voice, opts)
  end

  defdelegate send_voice(chat_id, voice), to: Lux.Telegram.Media

  def send_audio(%__MODULE__{} = client, chat_id, audio, opts) do
    Lux.Telegram.Media.send_audio(chat_id, audio, merge_client_opts(client, opts))
  end

  def send_audio(%__MODULE__{} = client, chat_id, audio) do
    Lux.Telegram.Media.send_audio(chat_id, audio, merge_client_opts(client, %{}))
  end

  def send_audio(chat_id, audio, opts) do
    Lux.Telegram.Media.send_audio(chat_id, audio, opts)
  end

  defdelegate send_audio(chat_id, audio), to: Lux.Telegram.Media

  def send_video(%__MODULE__{} = client, chat_id, video, opts) do
    Lux.Telegram.Media.send_video(chat_id, video, merge_client_opts(client, opts))
  end

  def send_video(%__MODULE__{} = client, chat_id, video) do
    Lux.Telegram.Media.send_video(chat_id, video, merge_client_opts(client, %{}))
  end

  def send_video(chat_id, video, opts) do
    Lux.Telegram.Media.send_video(chat_id, video, opts)
  end

  defdelegate send_video(chat_id, video), to: Lux.Telegram.Media

  def get_file(%__MODULE__{} = client, file_id, opts) do
    Lux.Telegram.Media.get_file(file_id, merge_client_opts(client, opts))
  end

  def get_file(%__MODULE__{} = client, file_id) do
    Lux.Telegram.Media.get_file(file_id, merge_client_opts(client, %{}))
  end

  def get_file(file_id, opts) do
    Lux.Telegram.Media.get_file(file_id, opts)
  end

  defdelegate get_file(file_id), to: Lux.Telegram.Media

  def download_file(%__MODULE__{} = client, file_path_or_id, opts) do
    Lux.Telegram.Media.download_file(file_path_or_id, merge_client_opts(client, opts))
  end

  def download_file(%__MODULE__{} = client, file_path_or_id) do
    Lux.Telegram.Media.download_file(file_path_or_id, merge_client_opts(client, %{}))
  end

  def download_file(file_path_or_id, opts) do
    Lux.Telegram.Media.download_file(file_path_or_id, opts)
  end

  defdelegate download_file(file_path_or_id), to: Lux.Telegram.Media

  defp extract_client_and_opts(%__MODULE__{} = client), do: {client, []}

  defp extract_client_and_opts(opts) when is_list(opts) or is_map(opts) do
    opts_list = normalize_opts(opts)

    if Keyword.has_key?(opts_list, :token) or Keyword.has_key?(opts_list, :base_url) or Keyword.has_key?(opts_list, :req_options) or Keyword.has_key?(opts_list, :plug) do
      {new(opts_list), opts_list}
    else
      {new(), opts_list}
    end

  end

  defp extract_client_and_opts(_), do: {new(), []}

  defp merge_client_opts(%__MODULE__{} = client, opts) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}

    opts_map
    |> Map.put_new(:token, client.token)
    |> Map.put_new(:base_url, client.base_url)
    |> Map.put_new(:req_options, client.req_options)
  end
end

defimpl Inspect, for: Lux.Telegram.Client do
  def inspect(%Lux.Telegram.Client{base_url: base_url, req_options: req_options, token: token}, opts) do
    redacted_token = if token, do: "[REDACTED]", else: nil

    Inspect.Any.inspect(
      %Lux.Telegram.Client{token: redacted_token, base_url: base_url, req_options: req_options},
      opts
    )
  end
end
