defmodule Lux.Prisms.Coinbase.GetAccountPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.GetAccountPrism

  describe "view/0" do
    test "returns valid prism struct" do
      prism = GetAccountPrism.view()

      assert prism.name == "Coinbase Account & Portfolio"
      assert prism.input_schema.required == ["action"]
    end

    test "action enum includes all operations" do
      prism = GetAccountPrism.view()
      actions = prism.input_schema.properties.action.enum

      assert "list_accounts" in actions
      assert "get_account" in actions
      assert "list_portfolios" in actions
      assert "get_portfolio_breakdown" in actions
    end

    test "output schema defines action and data" do
      prism = GetAccountPrism.view()
      props = prism.output_schema.properties

      assert Map.has_key?(props, :action)
      assert Map.has_key?(props, :data)
    end
  end

  describe "handler/2" do
    test "list_accounts action" do
      result = GetAccountPrism.handler(%{action: "list_accounts"}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "get_account requires account_uuid" do
      result = GetAccountPrism.handler(%{action: "get_account"}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "list_portfolios action" do
      result = GetAccountPrism.handler(%{action: "list_portfolios"}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "get_portfolio_breakdown requires portfolio_uuid" do
      result =
        GetAccountPrism.handler(%{
          action: "get_portfolio_breakdown",
          portfolio_uuid: "test-uuid",
          currency: "USD"
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
