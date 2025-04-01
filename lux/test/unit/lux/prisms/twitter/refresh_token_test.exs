defmodule Lux.Prisms.Twitter.RefreshTokenTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.RefreshToken

  @client_id "test_client_id"
  @client_secret "test_client_secret"
  @refresh_token "test_refresh_token"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully refreshes a token using default credentials" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/oauth2/token"
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/x-www-form-urlencoded"]

        # Verify basic auth header present
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert length(auth_header) == 1
        assert hd(auth_header) =~ "Basic "

        # Check the form data
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "grant_type=refresh_token"
        assert body =~ "refresh_token="

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "access_token" => "new_access_token",
          "expires_in" => 7200
        }))
      end)

      assert {:ok, %{
        success: true,
        message: "Token refreshed successfully"
      }} = RefreshToken.handler(
        %{
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully refreshes a token with custom credentials" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/oauth2/token"

        # Check the form data has custom values
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "refresh_token=#{@refresh_token}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "access_token" => "new_custom_access_token",
          "expires_in" => 7200
        }))
      end)

      assert {:ok, %{
        success: true,
        message: "Token refreshed successfully"
      }} = RefreshToken.handler(
        %{
          client_id: @client_id,
          client_secret: @client_secret,
          refresh_token: @refresh_token,
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Twitter API error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/oauth2/token"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "detail" => "Invalid refresh token"
        }))
      end)

      assert {:error, %{
        success: false,
        message: message
      }} = RefreshToken.handler(
        %{
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )

      assert message =~ "Token refresh failed (401):"
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = RefreshToken.view()
      assert prism.input_schema.required == []
      assert Map.has_key?(prism.input_schema.properties, :client_id)
      assert Map.has_key?(prism.input_schema.properties, :client_secret)
      assert Map.has_key?(prism.input_schema.properties, :refresh_token)
    end

    test "validates output schema" do
      prism = RefreshToken.view()
      assert prism.output_schema.required == ["success", "message"]
      assert Map.has_key?(prism.output_schema.properties, :success)
      assert Map.has_key?(prism.output_schema.properties, :message)
    end
  end
end
