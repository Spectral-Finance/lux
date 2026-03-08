defmodule Lux.Integrations.Web3.Events.WebhookNotifierTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Events.WebhookNotifier

  setup do
    Req.Test.stub(Lux.Web3.WebhookOk, fn conn ->
      Plug.Conn.send_resp(conn, 200, "ok")
    end)

    Req.Test.stub(Lux.Web3.Webhook500, fn conn ->
      Plug.Conn.send_resp(conn, 500, "error")
    end)

    Req.Test.stub(Lux.Web3.Webhook404, fn conn ->
      Plug.Conn.send_resp(conn, 404, "not found")
    end)

    :ok
  end

  test "delivers event to webhook successfully" do
    event = %{type: :transfer, address: "0xtoken", block_number: 100, transaction_hash: "0xtx"}
    assert {:ok, %{status: 200, attempt: 1}} =
      WebhookNotifier.deliver("https://hook.example.com", event, plug: {Req.Test, Lux.Web3.WebhookOk})
  end

  test "includes HMAC signature when secret provided" do
    Req.Test.stub(Lux.Web3.WebhookSigned, fn conn ->
      sig = Enum.find_value(conn.req_headers, fn
        {"x-webhook-signature", v} -> v
        _ -> nil
      end)
      assert sig != nil
      assert String.starts_with?(sig, "sha256=")
      Plug.Conn.send_resp(conn, 200, "ok")
    end)

    event = %{type: :transfer, address: "0x", block_number: 1, transaction_hash: "0x"}
    assert {:ok, _} = WebhookNotifier.deliver("https://hook.example.com", event,
      secret: "mysecret", plug: {Req.Test, Lux.Web3.WebhookSigned})
  end

  test "returns error on 404 (no retry)" do
    event = %{type: :transfer, address: "0x", block_number: 1, transaction_hash: "0x"}
    assert {:error, %{status: 404}} =
      WebhookNotifier.deliver("https://hook.example.com", event, plug: {Req.Test, Lux.Web3.Webhook404})
  end

  test "verify_signature validates correctly" do
    payload = ~s({"test": true})
    secret = "test_secret"
    sig = :crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower)

    assert WebhookNotifier.verify_signature(payload, "sha256=#{sig}", secret)
    refute WebhookNotifier.verify_signature(payload, "sha256=wrong", secret)
  end

  test "deliver_to_subscribers sends to webhook subscribers only" do
    event = %{type: :transfer, address: "0x", block_number: 1, transaction_hash: "0x"}
    subs = [
      %{id: 1, webhook_url: "https://hook1.example.com"},
      %{id: 2, webhook_url: nil},  # no webhook — should be skipped
      %{id: 3, webhook_url: "https://hook2.example.com"}
    ]

    results = WebhookNotifier.deliver_to_subscribers(event, subs, plug: {Req.Test, Lux.Web3.WebhookOk})
    assert length(results) == 2
    assert Enum.all?(results, fn {_id, {:ok, _}} -> true; _ -> false end)
  end
end
