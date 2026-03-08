defmodule Lux.Prisms.YouTube.Community.PostSchedulerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.Community.PostScheduler

  setup do
    name = :"ps_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = PostScheduler.start_link(name: name)
    %{pid: pid}
  end

  test "schedule post", %{pid: pid} do
    {:ok, post} = PostScheduler.schedule_post(pid, %{text: "Hello!", scheduled_at: DateTime.utc_now() |> DateTime.add(3600)})
    assert post.status == :scheduled
  end

  test "cancel post", %{pid: pid} do
    {:ok, post} = PostScheduler.schedule_post(pid, %{text: "Cancel me", scheduled_at: DateTime.utc_now()})
    :ok = PostScheduler.cancel_post(pid, post.id)
    {:ok, posts} = PostScheduler.list_posts(pid)
    assert posts == []
  end

  test "cancel not found", %{pid: pid} do
    assert {:error, :not_found} = PostScheduler.cancel_post(pid, "nope")
  end

  test "get due posts", %{pid: pid} do
    past = DateTime.utc_now() |> DateTime.add(-60)
    future = DateTime.utc_now() |> DateTime.add(3600)
    {:ok, _} = PostScheduler.schedule_post(pid, %{text: "Due", scheduled_at: past})
    {:ok, _} = PostScheduler.schedule_post(pid, %{text: "Not due", scheduled_at: future})
    {:ok, due} = PostScheduler.get_due_posts(pid)
    assert length(due) == 1
    assert hd(due).text == "Due"
  end

  test "create campaign", %{pid: pid} do
    {:ok, c} = PostScheduler.create_campaign(pid, %{name: "Summer promo", start_date: ~D[2026-06-01]})
    assert c.name == "Summer promo"
    {:ok, campaigns} = PostScheduler.list_campaigns(pid)
    assert length(campaigns) == 1
  end

  test "cross-platform scheduling", %{pid: pid} do
    {:ok, post} = PostScheduler.schedule_post(pid, %{
      text: "Multi-platform!", scheduled_at: DateTime.utc_now(), platforms: [:youtube, :twitter, :instagram]
    })
    assert :twitter in post.platforms
  end
end
