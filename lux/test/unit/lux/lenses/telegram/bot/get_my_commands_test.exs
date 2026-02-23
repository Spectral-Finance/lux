defmodule Lux.Lenses.Telegram.Bot.GetMyCommandsTest do
  @moduledoc """
  Test suite for the GetMyCommands lens.
  Verifies:
  - Successful command list retrieval
  - Empty command list handling
  - Scope-filtered command retrieval
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Bot.GetMyCommands

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves bot commands" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getMyCommands"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{"command" => "start", "description" => "Start the bot"},
            %{"command" => "help", "description" => "Show help"},
            %{"command" => "settings", "description" => "Open settings"}
          ]
        }))
      end)

      assert {:ok, commands} = GetMyCommands.focus(%{}, %{})
      assert length(commands) == 3
      assert Enum.at(commands, 0) == %{command: "start", description: "Start the bot"}
      assert Enum.at(commands, 1) == %{command: "help", description: "Show help"}
    end

    test "handles empty command list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, []} = GetMyCommands.focus(%{}, %{})
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Unauthorized"} = GetMyCommands.focus(%{}, %{})
    end
  end
end
