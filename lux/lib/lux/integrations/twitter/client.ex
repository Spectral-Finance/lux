defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP Client for the Twitter API v2.
  Handles rate limiting and authentication headers automatically.
  """

  alias Lux.Integrations.Twitter

  @base_url "https://api.twitter.com/2"

  @type request_opts :: %{
          optional(:json) => map(),
          optional(:params) => Keyword.t() | map(),
          optional(:auth_opts) => Keyword.t()
        }

  @doc """
  Makes a request to the Twitter API v2.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    headers = Twitter.headers()

    req_opts =
      [
        method: method,
        url: @base_url <> path,
        headers: headers,
        params: Map.get(opts, :params, %{}),
        json: Map.get(opts, :json)
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    req = Req.new(req_opts)
    req = Twitter.add_auth_header(req)

    case Req.request(req) do
      {:ok, %{status: status, body: %{"data" => data}}} when status in 200..299 ->
        {:ok, data}

      {:ok, %{status: status, body: body}} when status in 200..299 ->
        # Some endpoints return data at root, some return it nested inside "data"
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end
end
