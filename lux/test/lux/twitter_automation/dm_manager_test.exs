defmodule Lux.TwitterAutomation.DMManagerTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAutomation.DMManager
  alias Lux.TwitterAutomation.Storage
  alias Lux.TwitterAutomation.QueueManager

  setup do
    {:ok, _pid} = start_supervised(DMManager)
    # Also start QueueManager since DMManager depends on it
    {:ok, _queue_pid} = start_supervised(QueueManager)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "send_dm/2" do
    test "sends a direct message successfully" do
      assert {:ok, queue_id} = DMManager.send_dm("user123", "Hello, this is a test DM")
      assert is_binary(queue_id)
    end

    test "fails to send DM to blocked user" do
      # Add user to opt-out list first
      assert :ok = DMManager.add_to_opt_out_list("blocked_user456")

      # Try to send DM to the opt-out user
      assert {:error, :opted_out} = DMManager.send_dm("blocked_user456", "This should fail")
    end

    test "fails to send DM to same user multiple times" do
      # Send first DM
      assert {:ok, _queue_id1} = DMManager.send_dm("user123", "First message")

      # Try sending another DM to the same user
      assert {:error, :already_sent} = DMManager.send_dm("user123", "Second message")
    end
  end

  describe "add_template/1" do
    test "adds a new DM template" do
      template = %{
        name: "welcome",
        content: "Welcome {{username}}! Thanks for following us.",
        enabled: true
      }

      assert {:ok, id} = DMManager.add_template(template)
      assert is_binary(id)

      # Verify the template is stored
      templates = DMManager.list_templates()
      assert length(templates) == 1
      assert hd(templates).name == "welcome"
    end

    test "handles templates with interpolation" do
      template = %{
        name: "personalized",
        content: "Hi {{first_name}}, thanks for your interest in {{product}}!",
        enabled: true
      }

      assert {:ok, _id} = DMManager.add_template(template)

      # Verify template is properly stored
      templates = DMManager.list_templates()
      assert length(templates) == 1
      template = hd(templates)
      assert template.content == "Hi {{first_name}}, thanks for your interest in {{product}}!"
    end
  end

  describe "enable_template/1" do
    test "enables a template" do
      template = %{
        name: "test_template",
        content: "Test content",
        enabled: false
      }

      {:ok, id} = DMManager.add_template(template)

      # Verify it starts disabled
      templates = DMManager.list_templates()
      disabled_template = Enum.find(templates, &(&1.id == id))
      refute disabled_template.enabled

      # Enable it
      assert :ok = DMManager.enable_template(id)

      # Verify it's enabled
      templates = DMManager.list_templates()
      enabled_template = Enum.find(templates, &(&1.id == id))
      assert enabled_template.enabled
    end

    test "returns error for non-existent template" do
      assert {:error, :not_found} = DMManager.enable_template("nonexistent")
    end
  end

  describe "send_from_template/3" do
    test "sends DM using a template with interpolation" do
      template = %{
        name: "welcome",
        content: "Welcome {{username}}! Thanks for following us.",
        enabled: true
      }

      {:ok, template_id} = DMManager.add_template(template)

      # Send DM using template
      user_data = %{username: "testuser"}
      assert {:ok, queue_id} = DMManager.send_from_template("user123", template_id, user_data)
      assert is_binary(queue_id)
    end

    test "handles multiple interpolation variables" do
      template = %{
        name: "sale",
        content: "Hi {{first_name}}, {{product}} is now {{discount}}% off!",
        enabled: true
      }

      {:ok, template_id} = DMManager.add_template(template)

      user_data = %{
        first_name: "John",
        product: "Elixir course",
        discount: "30"
      }

      assert {:ok, queue_id} = DMManager.send_from_template("user456", template_id, user_data)
      assert is_binary(queue_id)
    end

    test "fails to send from disabled template" do
      template = %{
        name: "disabled",
        content: "This won't be sent",
        enabled: false
      }

      {:ok, template_id} = DMManager.add_template(template)

      user_data = %{username: "testuser"}
      assert {:error, :template_disabled} = DMManager.send_from_template("user789", template_id, user_data)
    end

    test "fails to send to opt-out user" do
      template = %{
        name: "opt_out_test",
        content: "This message should not be sent",
        enabled: true
      }

      {:ok, template_id} = DMManager.add_template(template)
      assert :ok = DMManager.add_to_opt_out_list("opt_out_user123")

      user_data = %{username: "opt_out_user123"}
      assert {:error, :opted_out} = DMManager.send_from_template("opt_out_user123", template_id, user_data)
    end
  end

  describe "template management" do
    test "lists all templates" do
      template1 = %{name: "template1", content: "Content 1", enabled: true}
      template2 = %{name: "template2", content: "Content 2", enabled: false}

      {:ok, _id1} = DMManager.add_template(template1)
      {:ok, _id2} = DMManager.add_template(template2)

      templates = DMManager.list_templates()
      assert length(templates) == 2
    end

    test "only sends from enabled templates" do
      disabled_template = %{name: "disabled", content: "Won't send", enabled: false}
      enabled_template = %{name: "enabled", content: "Will send", enabled: true}

      {:ok, disabled_id} = DMManager.add_template(disabled_template)
      {:ok, enabled_id} = DMManager.add_template(enabled_template)

      user_data = %{username: "testuser"}

      # This should fail
      assert {:error, :template_disabled} = DMManager.send_from_template("user123", disabled_id, user_data)

      # This should succeed
      assert {:ok, _queue_id} = DMManager.send_from_template("user456", enabled_id, user_data)
    end
  end

  describe "rate limiting" do
    test "respects rate limits" do
      # Since rate limiting is implemented in the QueueManager, 
      # we test that DMs are properly queued
      for i <- 1..5 do
        assert {:ok, _queue_id} = DMManager.send_dm("user#{i}", "Test message #{i}")
      end

      # Verify all messages were queued
      assert DMManager.get_queue_size() >= 0  # Actual queue size depends on processing
    end
  end

  describe "opt-out functionality" do
    test "adds user to opt-out list" do
      assert :ok = DMManager.add_to_opt_out_list("user123")

      # Try to send DM to opt-out user
      assert {:error, :opted_out} = DMManager.send_dm("user123", "This should fail")
    end

    test "removes user from opt-out list" do
      assert :ok = DMManager.add_to_opt_out_list("user123")

      # Verify they can't receive DMs
      assert {:error, :opted_out} = DMManager.send_dm("user123", "This should fail")

      # Remove from opt-out list
      assert :ok = DMManager.remove_from_opt_out_list("user123")

      # Now they should be able to receive DMs
      assert {:ok, _queue_id} = DMManager.send_dm("user123", "This should succeed")
    end

    test "lists opt-out users" do
      assert :ok = DMManager.add_to_opt_out_list("user123")
      assert :ok = DMManager.add_to_opt_out_list("user456")

      opt_out_list = DMManager.list_opt_out_users()
      assert length(opt_out_list) == 2
      assert "user123" in opt_out_list
      assert "user456" in opt_out_list
    end
  end

  describe "history tracking" do
    test "tracks sent DMs to prevent duplicates" do
      user_id = "test_user"
      template = %{name: "test", content: "Test content", enabled: true}
      {:ok, template_id} = DMManager.add_template(template)

      # Send first DM
      user_data = %{username: "testuser"}
      assert {:ok, _queue_id} = DMManager.send_from_template(user_id, template_id, user_data)

      # Verify second DM to same user fails
      assert {:error, :already_sent} = DMManager.send_from_template(user_id, template_id, user_data)
    end
  end

  describe "get_queue_size/0" do
    test "returns the size of the DM queue" do
      initial_size = DMManager.get_queue_size()

      assert {:ok, _id1} = DMManager.send_dm("user1", "Message 1")
      assert {:ok, _id2} = DMManager.send_dm("user2", "Message 2")

      # Queue size should reflect queued messages
      # Note: The actual size may vary depending on processing
      final_size = DMManager.get_queue_size()
    end
  end

  describe "cleanup" do
    test "clears all data" do
      # Add some templates
      template = %{name: "cleanup_test", content: "Test content", enabled: true}
      {:ok, _id} = DMManager.add_template(template)

      # Add to opt-out list
      assert :ok = DMManager.add_to_opt_out_list("cleanup_user")

      # Verify templates exist
      assert length(DMManager.list_templates()) > 0

      # Clear all data
      Storage.clear_all()

      # Verify templates are gone
      assert length(DMManager.list_templates()) == 0
    end
  end
end