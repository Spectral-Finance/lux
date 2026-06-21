defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  Basic HTTP client for X (Twitter) API v2 requests.
  """

  require Logger

  @endpoint "https://api.twitter.com/2"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:params) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the X (Twitter) API v2.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || Lux.Config.twitter_bearer_token()

    [
      method: method,
      url: @endpoint <> path,
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ],
      json: opts[:json],
      params: opts[:params]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 403, body: body}} ->
        # Common for duplicate tweets
        Logger.warning("Twitter API 403: #{inspect(body)}")
        {:error, {:forbidden, body}}

      {:ok, %{status: 429, body: body}} ->
        Logger.warning("Twitter API Rate Limit: #{inspect(body)}")
        {:error, {:rate_limit, body}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
