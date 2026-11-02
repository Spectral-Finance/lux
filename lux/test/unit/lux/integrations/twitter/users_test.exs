defmodule Lux.Integrations.Twitter.UsersTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Users

  describe "users lookup" do
    test "get_me/1 fetches authenticated user" do
      plug = fn conn ->
        assert conn.request_path == "/users/me"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "999888",
              "name" => "Lux Agent",
              "username" => "lux_agent_official"
            }
          })
        )
      end

      {:ok, result} = Users.get_me(%{plug: plug})
      assert result["data"]["id"] == "999888"
      assert result["data"]["username"] == "lux_agent_official"
    end

    test "get_user_by_username/2 fetches user by handle" do
      plug = fn conn ->
        assert conn.request_path == "/users/by/username/Spectral_Fi"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "1450000000000000000",
              "name" => "Spectral",
              "username" => "Spectral_Fi",
              "verified" => true
            }
          })
        )
      end

      {:ok, result} = Users.get_user_by_username("@Spectral_Fi", %{plug: plug})
      assert result["data"]["username"] == "Spectral_Fi"
      assert result["data"]["verified"] == true
    end

    test "get_user_by_id/2 fetches user by ID" do
      plug = fn conn ->
        assert conn.request_path == "/users/123456"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "123456",
              "name" => "Developer",
              "username" => "dev_user"
            }
          })
        )
      end

      {:ok, result} = Users.get_user_by_id("123456", %{plug: plug})
      assert result["data"]["id"] == "123456"
      assert result["data"]["name"] == "Developer"
    end
  end
end
