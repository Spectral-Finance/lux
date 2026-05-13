defmodule Lux.Prisms.YouTube.LiveWorkflowTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.Live.BindBroadcast
  alias Lux.Prisms.YouTube.Live.CreateBroadcast
  alias Lux.Prisms.YouTube.Live.CreateStream
  alias Lux.Prisms.YouTube.Live.SendChatMessage
  alias Lux.Prisms.YouTube.Live.TransitionBroadcast
  alias Lux.Prisms.YouTube.Videos.InitiateResumableUpload

  @token "ya29.test-token"
  @agent_ctx %{name: "YouTubeAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "initiates a video upload session" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/upload/youtube/v3/videos"
      assert conn.query_string =~ "uploadType=resumable"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{@token}"]

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["snippet", "title"]) == "Demo"
      assert get_in(decoded, ["status", "privacyStatus"]) == "unlisted"

      conn
      |> Plug.Conn.put_resp_header("location", "https://upload.youtube.test/session")
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
    end)

    assert {:ok,
            %{
              upload_url: "https://upload.youtube.test/session",
              title: "Demo",
              privacy_status: "unlisted"
            }} =
             InitiateResumableUpload.handler(
               %{title: "Demo", privacy_status: "unlisted", token: @token},
               @agent_ctx
             )
  end

  test "creates a live broadcast" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["snippet", "title"]) == "Launch"
      assert get_in(decoded, ["snippet", "scheduledStartTime"]) == "2026-05-13T12:00:00Z"
      assert get_in(decoded, ["contentDetails", "enableAutoStop"]) == true

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
    end)

    assert {:ok, %{broadcast_id: "broadcast-1", title: "Launch"}} =
             CreateBroadcast.handler(
               %{
                 title: "Launch",
                 scheduled_start_time: "2026-05-13T12:00:00Z",
                 token: @token
               },
               @agent_ctx
             )
  end

  test "creates and binds a live stream" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveStreams"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["snippet", "title"]) == "Primary"
      assert get_in(decoded, ["cdn", "ingestionType"]) == "rtmp"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "stream-1"}))
    end)

    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"
      assert conn.query_string =~ "id=broadcast-1"
      assert conn.query_string =~ "streamId=stream-1"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
    end)

    assert {:ok, %{stream_id: "stream-1", title: "Primary"}} =
             CreateStream.handler(%{title: "Primary", token: @token}, @agent_ctx)

    assert {:ok, %{bound: true, broadcast_id: "broadcast-1", stream_id: "stream-1"}} =
             BindBroadcast.handler(
               %{broadcast_id: "broadcast-1", stream_id: "stream-1", token: @token},
               @agent_ctx
             )
  end

  test "transitions a live broadcast" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"
      assert conn.query_string =~ "broadcastStatus=live"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
    end)

    assert {:ok, %{transitioned: true, broadcast_id: "broadcast-1", status: "live"}} =
             TransitionBroadcast.handler(
               %{broadcast_id: "broadcast-1", status: "live", token: @token},
               @agent_ctx
             )
  end

  test "sends a live chat message" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveChat/messages"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["snippet", "liveChatId"]) == "chat-1"
      assert get_in(decoded, ["snippet", "textMessageDetails", "messageText"]) == "hello"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "message-1"}))
    end)

    assert {:ok, %{sent: true, message_id: "message-1", live_chat_id: "chat-1", text: "hello"}} =
             SendChatMessage.handler(
               %{live_chat_id: "chat-1", text: "hello", token: @token},
               @agent_ctx
             )
  end

  test "validates required parameters and schemas" do
    assert {:error, "Missing or invalid title"} = CreateBroadcast.handler(%{}, @agent_ctx)

    assert {:error, "Missing or invalid status"} =
             TransitionBroadcast.handler(%{broadcast_id: "b1"}, @agent_ctx)

    broadcast = CreateBroadcast.view()
    assert broadcast.input_schema.required == ["title", "scheduled_start_time"]
    assert Map.has_key?(broadcast.input_schema.properties, :privacy_status)

    chat = SendChatMessage.view()
    assert chat.output_schema.required == ["sent", "live_chat_id", "text"]
  end
end
