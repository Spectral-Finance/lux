defmodule Lux.Prisms.Discord.Voice.ListRegionsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Voice.ListRegions

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "lists voice regions" do
      mock_regions = [
        %{"id" => "us-west", "name" => "US West", "optimal" => true},
        %{"id" => "us-east", "name" => "US East", "optimal" => false}
      ]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/voice/regions"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_regions))
      end)

      {:ok, result} = ListRegions.handler(%{}, Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock}))
      assert result.count == 2
      assert length(result.regions) == 2
    end

    test "propagates API errors" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"message" => "Internal Server Error"}))
      end)

      {:error, {500, "Internal Server Error"}} =
        ListRegions.handler(%{}, Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock}))
    end

    test "handles unexpected response" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!("unexpected"))
      end)

      {:error, {:unexpected_response, _}} =
        ListRegions.handler(%{}, Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock}))
    end
  end
end
