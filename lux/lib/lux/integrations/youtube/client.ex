defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  Small HTTP client for YouTube Data API v3 and resumable-upload session requests.
  """

  @data_endpoint "https://www.googleapis.com/youtube/v3"
  @upload_endpoint "https://www.googleapis.com/upload/youtube/v3"

  @type endpoint :: :data | :upload
  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:endpoint) => endpoint(),
          optional(:params) => map(),
          optional(:json) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()}
        }

  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || Lux.Config.youtube_access_token()

    [method: method, url: endpoint(opts[:endpoint]) <> path]
    |> Keyword.put(:headers, headers(token, opts[:headers] || []))
    |> maybe_put(:params, opts[:params])
    |> maybe_put(:json, opts[:json])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp endpoint(:upload), do: @upload_endpoint
  defp endpoint(_), do: @data_endpoint

  defp headers(token, extra_headers) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ] ++ extra_headers
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, value) when value == %{}, do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    cond do
      location = upload_location(response) -> {:ok, %{"upload_url" => location}}
      is_map(response.body) -> {:ok, response.body}
      is_list(response.body) -> {:ok, %{"items" => response.body}}
      response.body in [nil, ""] -> {:ok, %{}}
      true -> {:ok, %{"body" => response.body}}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, {status, error_message(body)}}

  defp handle_response({:error, error}), do: {:error, error}

  defp upload_location(%{headers: headers}) do
    headers
    |> Enum.find_value(fn {name, value} ->
      if String.downcase(to_string(name)) == "location", do: first_header(value)
    end)
  end

  defp first_header([value | _]), do: value
  defp first_header(value), do: value

  defp error_message(%{"error" => %{"message" => message}}), do: message
  defp error_message(%{"error" => message}) when is_binary(message), do: message
  defp error_message(%{"message" => message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(error), do: inspect(error)
end
