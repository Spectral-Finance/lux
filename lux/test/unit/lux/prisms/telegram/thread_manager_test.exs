defmodule Lux.Prisms.Telegram.ThreadManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.ThreadManager

  setup do
    Req.Test.stub(Lux.Telegram.ForumMock, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      result = cond do
        String.contains?(conn.request_path, "createForumTopic") ->
          %{"message_thread_id" => 42, "name" => decoded["name"], "icon_color" => 7322096}
        String.contains?(conn.request_path, "getForumTopicIconStickers") ->
          [%{"emoji" => "📝", "set_name" => "TopicIcons"}]
        true ->
          true
      end

      Req.Test.json(conn, %{"ok" => true, "result" => result})
    end)
    :ok
  end

  test "create forum topic" do
    {:ok, %{"result" => result}} = ThreadManager.handler(%{
      action: "create_topic", token: "t", chat_id: -100,
      name: "Test Topic",
      plug: {Req.Test, Lux.Telegram.ForumMock}
    }, nil)

    assert result["name"] == "Test Topic"
    assert result["message_thread_id"] == 42
  end

  test "close forum topic" do
    {:ok, %{"result" => true}} = ThreadManager.handler(%{
      action: "close_topic", token: "t", chat_id: -100,
      message_thread_id: 42,
      plug: {Req.Test, Lux.Telegram.ForumMock}
    }, nil)
  end

  test "reopen forum topic" do
    {:ok, %{"result" => true}} = ThreadManager.handler(%{
      action: "reopen_topic", token: "t", chat_id: -100,
      message_thread_id: 42,
      plug: {Req.Test, Lux.Telegram.ForumMock}
    }, nil)
  end

  test "delete forum topic" do
    {:ok, %{"result" => true}} = ThreadManager.handler(%{
      action: "delete_topic", token: "t", chat_id: -100,
      message_thread_id: 42,
      plug: {Req.Test, Lux.Telegram.ForumMock}
    }, nil)
  end

  test "get topic icon stickers" do
    {:ok, %{"result" => stickers}} = ThreadManager.handler(%{
      action: "get_topic", token: "t", chat_id: -100,
      plug: {Req.Test, Lux.Telegram.ForumMock}
    }, nil)

    assert length(stickers) == 1
  end
end
