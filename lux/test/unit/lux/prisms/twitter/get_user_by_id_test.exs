defmodule Lux.Prisms.Twitter.GetUserByIdTest do
  @moduledoc """
  Test suite for the GetUserById prism.
  """

  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.GetUserById
  alias Lux.Integrations.Telegram.Client, as: TelegramClient

  @agent_ctx %{name: "TestAgent"}
  @user_id "123456789"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully fetches user by ID" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/users/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @user_id,
            "name" => "John Doe",
            "username" => "johndoe",
            "verified" => true,
            "description" => "Software engineer",
            "public_metrics" => %{
              "followers_count" => 1000,
              "following_count" => 500,
              "tweet_count" => 10000,
              "listed_count" => 50
            }
          }
        }))
      end)

      assert {:ok, %{id: ^@user_id, name: "John Doe", username: "johndoe"}} =
               GetUserById.handler(%{user_id: @user_id}, @agent_ctx)
    end

    test "handles user not found" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Could not find User with id: #{@user_id}"}]
        }))
      end)

      assert {:error, {404, "Could not find User with id: #{@user_id}"}} =
               GetUserById.handler(%{user_id: @user_id}, @agent_ctx)
    end

    test "rejects missing user_id" do
      assert {:error, "Missing or invalid user_id"} =
               GetUserById.handler(%{}, @agent_ctx)
    end
  end
end
