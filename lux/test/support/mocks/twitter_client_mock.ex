defmodule Lux.Test.Mocks.TwitterClientMock do
  @moduledoc """
  Mock for Twitter API client testing.

  This mock is used in unit tests for Twitter API interactions, allowing tests to run without
  making actual HTTP requests to Twitter.
  """

  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # Set the base path for the Twitter API
    conn = put_private(conn, :req_test_base_path, "/api/v2")

    # Simulate Twitter API responses
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, Jason.encode!(%{"detail" => "Not Found: Path not handled by mock"}))
  end
end
