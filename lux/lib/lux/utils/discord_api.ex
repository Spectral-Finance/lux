defmodule Lux.Utils.DiscordApi do
  @moduledoc """
  Utility for communicating with Discord REST API and handling rate limits.
  """

  @base_url "https://discord.com/api/v10"

  def request(method, path, body \\ nil) do
    req = 
      Req.new(
        method: method,
        url: @base_url <> path,
        headers: [
          {"Authorization", "Bot #{Lux.Config.discord_api_key()}"},
          {"Content-Type", "application/json"}
        ]
      )

    req = if body, do: Req.merge(req, json: body), else: req

    Req.request(req)
    |> handle_response()
  end

  def handle_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  def handle_response({:ok, %Req.Response{status: 429, body: body}}) do
    retry_after = Map.get(body, "retry_after", 1.0)
    {:error, :rate_limit, retry_after}
  end

  def handle_response({:ok, %Req.Response{body: body}}) do
    {:error, body}
  end

  def handle_response({:error, reason}) do
    {:error, reason}
  end
end
