defmodule Lux.Beams.YouTube.ContentCreationPipelineBeamTest do
  use ExUnit.Case, async: true
  alias Lux.Beams.YouTube.ContentCreationPipelineBeam
  alias Lux.LLM.OpenAI
  alias Lux.Prisms.YouTube.UploadVideoPrism
  alias Lux.Prisms.YouTube.SetMetadataPrism
  alias Lux.Prisms.YouTube.PlaylistManagerPrism

  setup do
    Application.put_env(:lux, UploadVideoPrism, plug: {Req.Test, UploadVideoPrism})
    Application.put_env(:lux, SetMetadataPrism, plug: {Req.Test, SetMetadataPrism})
    Application.put_env(:lux, PlaylistManagerPrism, plug: {Req.Test, PlaylistManagerPrism})
    
    Application.put_env(:lux, Lux.LLM.OpenAI, plug: {Req.Test, OpenAI})
    Application.put_env(:lux, :api_keys, %{openai: "fake"})
    Application.put_env(:lux, :open_ai_models, %{default: "fake"})

    Req.Test.verify_on_exit!()
    :ok
  end

  test "successfully traces the content creation sequence" do
    Req.Test.expect(OpenAI, 3, fn conn ->
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      
      cond do
        String.contains?(hd(decoded["messages"])["content"], "Generate a script") ->
          Plug.Conn.put_resp_content_type(conn, "application/json")
          |> Plug.Conn.send_resp(200, ~s({"id": "chatcmpl-1", "model": "fake", "choices": [{"message": {"content": "{\\"script\\": \\"fake script\\"}"}, "finish_reason": "stop"}]}))
        String.contains?(hd(decoded["messages"])["content"], "YouTube SEO expert") ->
          Plug.Conn.put_resp_content_type(conn, "application/json")
          |> Plug.Conn.send_resp(200, ~s({"id": "chatcmpl-2", "model": "fake", "choices": [{"message": {"content": "{\\"title\\": \\"Fake Title\\", \\"description\\": \\"Fake Desc\\", \\"tags\\": [\\"fake\\"]}"}, "finish_reason": "stop"}]}))
        String.contains?(hd(decoded["messages"])["content"], "generate a thumbnail") ->
          Plug.Conn.put_resp_content_type(conn, "application/json")
          |> Plug.Conn.send_resp(200, ~s({"id": "chatcmpl-3", "model": "fake", "choices": [{"message": {"content": "{\\"thumbnail_url\\": \\"https://fake.com/thumb.png\\"}"}, "finish_reason": "stop"}]}))
      end
    end)
    
    Req.Test.expect(UploadVideoPrism, 2, fn conn ->
      if conn.method == "POST" do
        Plug.Conn.put_resp_header(conn, "location", "https://example.com/upload?upload_id=123")
        |> Plug.Conn.send_resp(200, "")
      else
        Plug.Conn.put_resp_content_type(conn, "application/json")
        |> Plug.Conn.send_resp(200, ~s({"id": "vid123"}))
      end
    end)

    Req.Test.expect(SetMetadataPrism, fn conn ->
      Plug.Conn.put_resp_content_type(conn, "application/json")
      |> Plug.Conn.send_resp(200, ~s({"id": "vid123"}))
    end)

    Req.Test.expect(PlaylistManagerPrism, fn conn ->
      Plug.Conn.put_resp_content_type(conn, "application/json")
      |> Plug.Conn.send_resp(200, ~s({"id": "playlist_item_123"}))
    end)

    result = ContentCreationPipelineBeam.run(%{
      prompt: "test prompt",
      playlist_id: "PL123",
      access_token: "fake_token"
    })

    assert {:ok, %{video_id: "vid123", playlist_success: true}, _log} = result
  end
end
