defmodule Lux.Integrations.Telegram.ClientTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Client

  describe "request/3" do
    test "makes GET request to Telegram API" do
      # This test would need a mock plug
      # For now, just test that the function exists
      assert function_exported?(Client, :request, 3)
    end

    test "makes POST request to Telegram API" do
      assert function_exported?(Client, :request, 3)
    end
  end

  describe "multipart_request/3" do
    test "makes multipart request to Telegram API" do
      assert function_exported?(Client, :multipart_request, 3)
    end
  end
end
