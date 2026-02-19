defmodule Lux.Lenses.Coinbase.AccountsLensTest do
  @moduledoc """
  Test suite for the Coinbase Accounts lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.AccountsLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses accounts response" do
      response = %{
        "accounts" => [
          %{
            "uuid" => "abc-123",
            "name" => "BTC Wallet",
            "currency" => "BTC",
            "available_balance" => %{"value" => "1.5", "currency" => "BTC"},
            "hold" => %{"value" => "0.1", "currency" => "BTC"},
            "type" => "ACCOUNT_TYPE_CRYPTO",
            "ready" => true,
            "default" => true,
            "active" => true,
            "created_at" => "2024-01-01T00:00:00Z",
            "updated_at" => "2024-01-15T12:00:00Z"
          },
          %{
            "uuid" => "def-456",
            "name" => "USD Wallet",
            "currency" => "USD",
            "available_balance" => %{"value" => "10000.00", "currency" => "USD"},
            "hold" => %{"value" => "500.00", "currency" => "USD"},
            "type" => "ACCOUNT_TYPE_FIAT",
            "ready" => true,
            "default" => false,
            "active" => true,
            "created_at" => "2024-01-01T00:00:00Z",
            "updated_at" => "2024-01-15T12:00:00Z"
          }
        ],
        "cursor" => "next-page-cursor",
        "has_next" => true
      }

      assert {:ok, result} = AccountsLens.after_focus(response)
      assert length(result.accounts) == 2
      assert result.cursor == "next-page-cursor"
      assert result.has_next == true

      btc_account = Enum.find(result.accounts, &(&1.currency == "BTC"))
      assert btc_account.uuid == "abc-123"
      assert btc_account.name == "BTC Wallet"
      assert btc_account.available_balance == %{"value" => "1.5", "currency" => "BTC"}
      assert btc_account.hold == %{"value" => "0.1", "currency" => "BTC"}
      assert btc_account.ready == true
    end

    test "handles response without pagination" do
      response = %{
        "accounts" => [
          %{
            "uuid" => "abc-123",
            "name" => "BTC Wallet",
            "currency" => "BTC",
            "available_balance" => %{"value" => "1.5", "currency" => "BTC"},
            "hold" => %{"value" => "0.0", "currency" => "BTC"},
            "type" => "ACCOUNT_TYPE_CRYPTO",
            "ready" => true,
            "default" => true,
            "active" => true,
            "created_at" => "2024-01-01T00:00:00Z",
            "updated_at" => "2024-01-15T12:00:00Z"
          }
        ]
      }

      assert {:ok, result} = AccountsLens.after_focus(response)
      assert length(result.accounts) == 1
      refute Map.has_key?(result, :cursor)
      refute Map.has_key?(result, :has_next)
    end

    test "handles error response" do
      assert {:error, "Unauthorized"} =
               AccountsLens.after_focus(%{"error" => "Unauthorized"})
    end

    test "handles empty accounts list" do
      assert {:ok, %{accounts: []}} = AccountsLens.after_focus(%{"accounts" => []})
    end
  end
end
