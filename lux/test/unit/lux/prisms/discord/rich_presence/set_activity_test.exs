defmodule Lux.Prisms.Discord.RichPresence.SetActivityTest do
  @moduledoc """
  Test suite for SetActivity prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.RichPresence.SetActivity

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets playing activity" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/settings"
        
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["activities"][0]["name"] == "Lux Framework"
        assert Jason.decode!(body)["activities"][0]["type"] == 0

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "activities" => [%{"name" => "Lux Framework", "type" => 0, "state" => "building"}]
        }))
      end)

      assert {:ok, %{updated: true, activity: %{name: "Lux Framework", type: 0}}} =
               SetActivity.handler(
                 %{
                   type: 0,
                   name: "Lux Framework",
                   details: "Building Discord prisms",
                   state: "building"
                 },
                 @agent_ctx
               )
    end

    test "validates streaming requires URL" do
      assert {:error, "Streaming activity type requires a URL"} =
               SetActivity.handler(
                 %{
                   type: 1,
                   name: "Test Stream"
                 },
                 @agent_ctx
               )
    end

    test "successfully sets streaming activity with URL" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "activities" => [%{"name" => "Test Stream", "type" => 1, "state" => "live"}]
        }))
      end)

      assert {:ok, %{updated: true, activity: %{name: "Test Stream", type: 1}}} =
               SetActivity.handler(
                 %{
                   type: 1,
                   name: "Test Stream",
                   url: "https://twitch.tv/test"
                 },
                 @agent_ctx
               )
    end
  end
end