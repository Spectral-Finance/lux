defmodule Lux.Prisms.YouTube.SetMetadataPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.SetMetadataPrism

  setup do
    Application.put_env(:lux, SetMetadataPrism, plug: {Req.Test, SetMetadataPrism})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "updates video metadata" do
    Req.Test.expect(SetMetadataPrism, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/youtube/v3/videos"
      assert conn.query_string == "part=snippet"
      
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["id"] == "vid123"
      assert decoded["snippet"]["title"] == "New Title"

      Plug.Conn.send_resp(conn, 200, ~s({"id": "vid123"}))
    end)

    result = SetMetadataPrism.handler(%{
      "video_id" => "vid123",
      "title" => "New Title",
      "access_token" => "fake_token"
    }, nil)

    assert {:ok, %{success: true}} = result
  end
end
