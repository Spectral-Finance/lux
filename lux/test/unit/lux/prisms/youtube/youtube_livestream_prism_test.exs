defmodule Lux.Prisms.YouTube.YouTubeLivestreamPrismTest do
  use UnitCase, async: true
  alias Lux.Prisms.YouTube.YouTubeLivestreamPrism

  @moduletag :unit

  setup do
    System.put_env("YOUTUBE_API_KEY", "test_api_key")
    :ok
  end

  test "create broadcast returns success" do
    Req.Test.stub(YouTubeLivestreamPrism, fn conn ->
      Req.Test.json(conn, %{
        "id" => "broadcast123",
        "snippet" => %{"title" => "Test Stream", "scheduledStartTime" => "2026-06-14T10:00:00Z"},
        "status" => %{"lifeCycleStatus" => "created", "privacyStatus" => "public"}
      })
    end)
    {:ok, result} = YouTubeLivestreamPrism.handler(%{
      action: "create",
      title: "Test Stream",
      privacy: "public"
    }, %{})
    assert result.status == "success"
    assert result.broadcast.id == "broadcast123"
  end

  test "list broadcasts returns success" do
    Req.Test.stub(YouTubeLivestreamPrism, fn conn ->
      Req.Test.json(conn, %{
        "items" => [%{
          "id" => "broadcast123",
          "snippet" => %{"title" => "Test Stream", "scheduledStartTime" => "2026-06-14T10:00:00Z"},
          "status" => %{"lifeCycleStatus" => "ready", "privacyStatus" => "public"}
        }]
      })
    end)
    {:ok, result} = YouTubeLivestreamPrism.handler(%{action: "list"}, %{})
    assert result.status == "success"
    assert length(result.broadcasts) == 1
  end

  test "start broadcast transitions to live" do
    Req.Test.stub(YouTubeLivestreamPrism, fn conn ->
      Req.Test.json(conn, %{
        "id" => "broadcast123",
        "snippet" => %{"title" => "Test Stream", "scheduledStartTime" => "2026-06-14T10:00:00Z"},
        "status" => %{"lifeCycleStatus" => "live", "privacyStatus" => "public"}
      })
    end)
    {:ok, result} = YouTubeLivestreamPrism.handler(%{
      action: "start",
      broadcast_id: "broadcast123"
    }, %{})
    assert result.status == "success"
    assert result.broadcast.status == "live"
  end

  test "unknown action returns error" do
    result = YouTubeLivestreamPrism.handler(%{action: "unknown"}, %{})
    assert {:error, _} = result
  end
end
