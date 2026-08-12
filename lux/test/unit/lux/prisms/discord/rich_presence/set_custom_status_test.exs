defmodule Lux.Prisms.Discord.RichPresence.SetCustomStatusTest do
  @moduledoc """
  Test suite for SetCustomStatus prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.RichPresence.SetCustomStatus

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets custom status" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/settings"
        
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "custom_status" => %{
            "text" => "Testing",
            "emoji_name" => "robot",
            "emoji_animated" => false
          }
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "custom_status" => %{
            "text" => "Testing",
            "emoji_name" => "robot",
            "emoji_id" => nil,
            "expires_at" => nil
          }
        }))
      end)

      assert {:ok, %{updated: true, custom_status: status}} =
               SetCustomStatus.handler(
                 %{
                   text: "Testing",
                   emoji_name: "robot",
                   emoji_animated: false
                 },
                 @agent_ctx
               )
    end

    test "handles empty custom status" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"custom_status" => nil}))
      end)

      assert {:ok, %{updated: true}} =
               SetCustomStatus.handler(%{}, @agent_ctx)
    end
  end
end