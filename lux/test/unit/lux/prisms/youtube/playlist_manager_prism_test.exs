defmodule Lux.Prisms.YouTube.PlaylistManagerPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.PlaylistManagerPrism

  setup do
    Application.put_env(:lux, PlaylistManagerPrism, plug: {Req.Test, PlaylistManagerPrism})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "inserts video into playlist" do
    Req.Test.expect(PlaylistManagerPrism, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/playlistItems"
      assert conn.query_string == "part=snippet"
      
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["snippet"]["playlistId"] == "PL123"
      assert decoded["snippet"]["resourceId"]["videoId"] == "vid123"

      Plug.Conn.send_resp(conn, 200, ~s({"id": "playlist_item_123"}))
    end)

    result = PlaylistManagerPrism.handler(%{
      "video_id" => "vid123",
      "playlist_id" => "PL123",
      "access_token" => "fake_token"
    }, nil)

    assert {:ok, %{success: true}} = result
  end
end
