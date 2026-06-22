alias Lux.Integrations.Telegram.Webhook

iterations =
  System.get_env("ITERATIONS", "100000")
  |> String.to_integer()

update = %{
  "update_id" => 1,
  "message" => %{
    "message_id" => 10,
    "chat" => %{"id" => 123},
    "text" => "hello"
  }
}

headers = [{"x-telegram-bot-api-secret-token", "benchmark-secret"}]

{type_us, :ok} =
  :timer.tc(fn ->
    for _ <- 1..iterations do
      :message = Webhook.update_type(update)
      123 = Webhook.chat_id(update)
    end

    :ok
  end)

{secret_us, :ok} =
  :timer.tc(fn ->
    for _ <- 1..iterations do
      true = Webhook.verify_secret_token(headers, "benchmark-secret")
    end

    :ok
  end)

IO.puts("telegram_update_helpers=#{type_us / iterations}us/op")
IO.puts("telegram_secret_verification=#{secret_us / iterations}us/op")
