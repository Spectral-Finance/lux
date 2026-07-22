defmodule Lux.Prisms.Telegram.Admin.AdminActionLoggerTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.AdminActionLogger

  @chat_id "123456789"
  @agent_ctx %{name: "SecurityAgent"}

  describe "handler/2" do
    test "successfully logs admin action with atom keys" do
      assert {:ok, response} = AdminActionLogger.handler(%{
        action_type: "BAN_USER",
        chat_id: @chat_id,
        target_user_id: 987654,
        details: %{reason: "Spamming"}
      }, @agent_ctx)

      assert response.logged == true
      assert response.log_entry.action_type == "BAN_USER"
      assert response.log_entry.chat_id == @chat_id
      assert response.log_entry.admin_id == "SecurityAgent"
      assert response.log_entry.target_user_id == 987654
      assert response.log_entry.details == %{reason: "Spamming"}
    end

    test "successfully logs admin action with string keys" do
      assert {:ok, response} = AdminActionLogger.handler(%{
        "action_type" => "SET_TITLE",
        "chat_id" => @chat_id,
        "admin_id" => "CustomAdmin"
      }, %{})

      assert response.logged == true
      assert response.log_entry.action_type == "SET_TITLE"
      assert response.log_entry.admin_id == "CustomAdmin"
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid action_type"} = AdminActionLogger.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert {:error, "Missing or invalid chat_id"} = AdminActionLogger.handler(%{action_type: "BAN_USER"}, @agent_ctx)
    end
  end
end
