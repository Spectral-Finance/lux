defmodule Lux.TwitterAutomation.ContentCalendarTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAutomation.ContentCalendar
  alias Lux.TwitterAutomation.Storage

  setup do
    {:ok, _pid} = start_supervised(ContentCalendar)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "add_content/3" do
    test "adds content to the calendar" do
      publish_date = DateTime.add(DateTime.utc_now(), 86400, :second)  # Tomorrow
      assert {:ok, id} = ContentCalendar.add_content("Test tweet content", publish_date)
      assert is_binary(id)

      # Verify the item is stored in Storage
      {:ok, item} = Storage.get_calendar_item(id)
      assert item.content == "Test tweet content"
      assert item.status == :draft
      assert item.publish_date == publish_date
    end

    test "adds content with tags and metadata" do
      publish_date = DateTime.add(DateTime.utc_now(), 86400, :second)
      opts = %{
        tags: ["elixir", "programming"],
        metadata: %{author: "test_user", campaign: "december"}
      }

      assert {:ok, id} = ContentCalendar.add_content("Content with metadata", publish_date, opts)

      {:ok, item} = Storage.get_calendar_item(id)
      assert item.tags == ["elixir", "programming"]
      assert item.metadata.author == "test_user"
      assert item.metadata.campaign == "december"
    end
  end

  describe "update_content/2" do
    test "updates an existing content item" do
      publish_date = DateTime.add(DateTime.utc_now(), 86400, :second)
      {:ok, id} = ContentCalendar.add_content("Original content", publish_date)

      # Verify original content
      {:ok, original_item} = Storage.get_calendar_item(id)
      assert original_item.content == "Original content"

      # Update the content
      changes = %{
        content: "Updated content",
        tags: ["updated", "test"],
        status: :scheduled
      }

      assert :ok = ContentCalendar.update_content(id, changes)

      # Verify the update
      {:ok, updated_item} = Storage.get_calendar_item(id)
      assert updated_item.content == "Updated content"
      assert updated_item.tags == ["updated", "test"]
      assert updated_item.status == :scheduled
    end

    test "returns error for non-existent item" do
      changes = %{content: "Updated content"}
      assert {:error, :not_found} = ContentCalendar.update_content("nonexistent", changes)
    end
  end

  describe "delete_content/1" do
    test "deletes an existing content item" do
      publish_date = DateTime.add(DateTime.utc_now(), 86400, :second)
      {:ok, id} = ContentCalendar.add_content("Content to delete", publish_date)

      # Verify it exists
      {:ok, _item} = Storage.get_calendar_item(id)

      # Delete it
      assert :ok = ContentCalendar.delete_content(id)

      # Verify it's gone
      assert {:error, :not_found} = Storage.get_calendar_item(id)
    end
  end

  describe "schedule_content/1" do
    test "schedules content for publishing" do
      publish_date = DateTime.add(DateTime.utc_now(), 3600, :second)  # 1 hour from now
      {:ok, id} = ContentCalendar.add_content("Content to schedule", publish_date)

      # Initially draft
      {:ok, draft_item} = Storage.get_calendar_item(id)
      assert draft_item.status == :draft

      # Schedule it
      assert {:ok, schedule_id} = ContentCalendar.schedule_content(id)
      assert is_binary(schedule_id)

      # Verify status is now scheduled
      {:ok, scheduled_item} = Storage.get_calendar_item(id)
      assert scheduled_item.status == :scheduled
      assert scheduled_item.metadata.schedule_id == schedule_id

      # Verify it's in the scheduler
      # Note: We're not testing the actual scheduling functionality in detail
      # as it depends on the Scheduler implementation
    end

    test "returns error for non-existent item" do
      assert {:error, :not_found} = ContentCalendar.schedule_content("nonexistent")
    end
  end

  describe "get_calendar/2" do
    test "returns content in date range" do
      now = DateTime.utc_now()
      date1 = DateTime.add(now, 86400, :second)   # Tomorrow
      date2 = DateTime.add(now, 172800, :second)  # In 2 days
      date3 = DateTime.add(now, 259200, :second)  # In 3 days

      {:ok, id1} = ContentCalendar.add_content("Content 1", date1, tags: ["tag1"])
      {:ok, id2} = ContentCalendar.add_content("Content 2", date2, tags: ["tag2"])
      {:ok, id3} = ContentCalendar.add_content("Content 3", date3, tags: ["tag3"])

      # Get calendar for tomorrow and in 2 days
      start_range = DateTime.add(date1, -3600, :second)
      end_range = DateTime.add(date2, 3600, :second)

      {:ok, items} = ContentCalendar.get_calendar(start_range, end_range)
      assert length(items) == 2
      item_ids = Enum.map(items, & &1.id)
      assert id1 in item_ids
      assert id2 in item_ids
      refute id3 in item_ids
    end

    test "returns empty list if no content in range" do
      now = DateTime.utc_now()
      date1 = DateTime.add(now, 86400, :second)   # Tomorrow

      {:ok, _id1} = ContentCalendar.add_content("Content 1", date1, tags: ["tag1"])

      # Range that doesn't include the content
      start_range = DateTime.add(now, -86400, :second)
      end_range = DateTime.add(now, -3600, :second)

      {:ok, items} = ContentCalendar.get_calendar(start_range, end_range)
      assert length(items) == 0
    end
  end

  describe "get_content_by_tag/1" do
    test "returns content with specific tag" do
      {:ok, id1} = ContentCalendar.add_content("Content 1", DateTime.add(DateTime.utc_now(), 86400, :second), tags: ["elixir", "programming"])
      {:ok, id2} = ContentCalendar.add_content("Content 2", DateTime.add(DateTime.utc_now(), 86400, :second), tags: ["phoenix", "web"])
      {:ok, id3} = ContentCalendar.add_content("Content 3", DateTime.add(DateTime.utc_now(), 86400, :second), tags: ["elixir", "testing"])

      items_with_elixir = ContentCalendar.get_content_by_tag("elixir")
      assert length(items_with_elixir) == 2
      item_ids = Enum.map(items_with_elixir, & &1.id)
      assert id1 in item_ids
      assert id3 in item_ids
      refute id2 in item_ids
    end

    test "returns empty list if no content with tag" do
      {:ok, _id1} = ContentCalendar.add_content("Content 1", DateTime.add(DateTime.utc_now(), 86400, :second), tags: ["elixir"])

      items_with_ruby = ContentCalendar.get_content_by_tag("ruby")
      assert length(items_with_ruby) == 0
    end
  end

  describe "get_content_by_status/1" do
    test "returns content with specific status" do
      now = DateTime.utc_now()
      future_date = DateTime.add(now, 86400, :second)

      {:ok, id1} = ContentCalendar.add_content("Draft 1", future_date, %{})
      {:ok, id2} = ContentCalendar.add_content("Draft 2", future_date, %{})
      {:ok, id3} = ContentCalendar.add_content("Scheduled content", future_date, %{})

      # Schedule one item
      ContentCalendar.schedule_content(id3)

      draft_items = ContentCalendar.get_content_by_status(:draft)
      assert length(draft_items) == 2
      draft_ids = Enum.map(draft_items, & &1.id)
      assert id1 in draft_ids
      assert id2 in draft_ids
      refute id3 in draft_ids

      scheduled_items = ContentCalendar.get_content_by_status(:scheduled)
      assert length(scheduled_items) == 1
      assert hd(scheduled_items).id == id3
    end

    test "returns empty list if no content with status" do
      {:ok, _id} = ContentCalendar.add_content("Draft content", DateTime.add(DateTime.utc_now(), 86400, :second))
      published_items = ContentCalendar.get_content_by_status(:published)
      assert length(published_items) == 0
    end
  end

  describe "content workflow" do
    test "goes from draft to scheduled" do
      publish_date = DateTime.add(DateTime.utc_now(), 3600, :second)
      {:ok, id} = ContentCalendar.add_content("Workflow test content", publish_date)

      # Initially draft
      {:ok, draft_item} = Storage.get_calendar_item(id)
      assert draft_item.status == :draft

      # Schedule it
      assert {:ok, _schedule_id} = ContentCalendar.schedule_content(id)

      # Now scheduled
      {:ok, scheduled_item} = Storage.get_calendar_item(id)
      assert scheduled_item.status == :scheduled
    end
  end

  describe "cleanup" do
    test "clears all content data" do
      publish_date = DateTime.add(DateTime.utc_now(), 86400, :second)
      {:ok, _id} = ContentCalendar.add_content("Test content", publish_date)
      draft_items = ContentCalendar.get_content_by_status(:draft)
      assert length(draft_items) > 0

      Storage.clear_all()
      draft_items = ContentCalendar.get_content_by_status(:draft)
      assert length(draft_items) == 0
    end
  end
end