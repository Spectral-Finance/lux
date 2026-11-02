defmodule Lux.Integrations.Telegram.GroupManagement.PermissionManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.GroupManagement.PermissionManager

  describe "PermissionManager" do
    test "get_preset/1 returns standard presets" do
      assert {:ok, read_only} = PermissionManager.get_preset(:read_only)
      assert read_only.can_send_messages == false
      assert read_only.can_send_photos == false

      assert {:ok, text_only} = PermissionManager.get_preset(:text_only)
      assert text_only.can_send_messages == true
      assert text_only.can_send_videos == false

      assert {:ok, standard} = PermissionManager.get_preset(:standard)
      assert standard.can_send_messages == true
      assert standard.can_send_photos == true

      assert {:error, {:unknown_preset, :non_existent}} =
               PermissionManager.get_preset(:non_existent)
    end

    test "validate_permissions/1 checks permission map keys" do
      valid = %{can_send_messages: true, can_pin_messages: false}
      assert {:ok, ^valid} = PermissionManager.validate_permissions(valid)

      invalid = %{can_send_messages: true, can_fly: true}
      assert {:error, [:can_fly]} = PermissionManager.validate_permissions(invalid)
    end

    test "set_chat_permissions/3 sends request via Client" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_999
        assert decoded["permissions"]["can_send_messages"] == false

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               PermissionManager.set_chat_permissions(-100_999, %{can_send_messages: false},
                 plug: plug
               )
    end

    test "has_permission?/2 evaluates creator and administrator privileges" do
      creator = %{status: "creator"}
      admin = %{status: "administrator", can_manage_chat: true}
      member_with_pin = %{status: "member", can_pin_messages: true}
      regular_member = %{status: "member", can_pin_messages: false}

      assert PermissionManager.has_permission?(creator, :can_pin_messages)
      assert PermissionManager.has_permission?(admin, :can_delete_messages)
      assert PermissionManager.has_permission?(member_with_pin, :can_pin_messages)
      refute PermissionManager.has_permission?(regular_member, :can_pin_messages)
    end
  end
end
