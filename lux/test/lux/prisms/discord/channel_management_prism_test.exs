defmodule Lux.Prisms.Discord.ChannelManagementPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Discord.ChannelManagementPrism

  describe "handler/2" do
    test "returns error for missing required params for update_permissions" do
      input = %{
        "action" => "update_permissions",
        "channel_id" => "123"
        # missing overwrite_id
      }
      assert {:error, "overwrite_id is required for update_permissions"} = ChannelManagementPrism.handler(input, nil)
    end

    test "returns error for missing channel_id for archive" do
      input = %{
        "action" => "archive"
      }
      assert {:error, "channel_id is required for archive"} = ChannelManagementPrism.handler(input, nil)
    end

    test "returns error for missing guild_id for create" do
      input = %{
        "action" => "create",
        "name" => "new-channel"
      }
      assert {:error, "guild_id and name are required for create"} = ChannelManagementPrism.handler(input, nil)
    end
  end
end
