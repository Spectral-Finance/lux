defmodule Lux.Lenses.Telegram.GetChatAdministratorsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.GetChatAdministrators

  @chat_id "123456789"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully gets chat administrators" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot/getChatAdministrators"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "status" => "creator",
              "user" => %{
                "id" => 11111,
                "is_bot" => false,
                "first_name" => "OwnerName",
                "username" => "owner"
              },
              "custom_title" => "Founder"
            },
            %{
              "status" => "administrator",
              "user" => %{
                "id" => 22222,
                "is_bot" => true,
                "first_name" => "ModBot",
                "username" => "mod_bot"
              }
            }
          ]
        }))
      end)

      assert {:ok, list} = GetChatAdministrators.focus(%{
        "chat_id" => @chat_id
      }, %{})

      assert length(list) == 2
      [owner, bot] = list
      assert owner.status == "creator"
      assert owner.user.first_name == "OwnerName"
      assert owner.custom_title == "Founder"
      assert bot.status == "administrator"
      assert bot.user.is_bot == true
    end

    test "handles error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Chat not found"
        }))
      end)

      assert {:error, message} = GetChatAdministrators.focus(%{
        "chat_id" => @chat_id
      }, %{})

      assert message == "Chat not found"
    end
  end
end
