defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP Client for Twitter API v2.
  """

  require Logger

  @endpoint "https://api.twitter.com/2"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:params) => keyword() | map(),
    optional(:headers) => [{String.t(), String.t()}]
  }

  @doc """
  Makes a request to the Twitter API v2.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    # Tokenni keyinchalik Config faylidan olamiz
    token = opts[:token] || Lux.Config.twitter_bearer_token()
    url = @endpoint <> path

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    [
      method: method,
      url: url,
      headers: headers,
      json: opts[:json],
      params: opts[:params]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    # Twitter ko'pincha javobni "data" kaliti ichida qaytaradi
    {:ok, response.body}
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %{status: 429}}) do
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, error}), do: {:error, error}
end
