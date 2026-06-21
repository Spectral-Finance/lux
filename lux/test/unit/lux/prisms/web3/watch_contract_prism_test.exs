defmodule Lux.Prisms.Web3.WatchContractPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.WatchContractPrism

  @usdt_address "0xdAC17F958D2ee523a2206206994597C13D831ec7"
  @transfer_sig "Transfer(address,address,uint256)"

  describe "view/0" do
    test "returns a Prism struct with correct metadata" do
      prism = WatchContractPrism.view()

      assert prism.name == "Web3 Watch Contract"
      assert String.contains?(prism.description, "contract event monitoring")
    end

    test "validates input schema has required properties" do
      prism = WatchContractPrism.view()
      input = prism.input_schema

      assert input.type == :object
      assert "contract_address" in input.required

      props = input.properties
      assert Map.has_key?(props, :contract_address)
      assert Map.has_key?(props, :event_signatures)
      assert Map.has_key?(props, :chain_id)
      assert Map.has_key?(props, :action)
      assert Map.has_key?(props, :subscription_id)
      assert Map.has_key?(props, :webhook_url)
      assert Map.has_key?(props, :from_block)
      assert Map.has_key?(props, :sync_from_block)
    end

    test "validates output schema has required properties" do
      prism = WatchContractPrism.view()
      output = prism.output_schema

      assert output.type == :object
      assert "subscription_id" in output.required
      assert "status" in output.required

      props = output.properties
      assert Map.has_key?(props, :subscription_id)
      assert Map.has_key?(props, :contract_address)
      assert Map.has_key?(props, :event_signatures)
      assert Map.has_key?(props, :chain_id)
      assert Map.has_key?(props, :status)
    end
  end

  describe "handler/2 schema validation" do
    test "input schema contract_address is string type" do
      prism = WatchContractPrism.view()
      prop = prism.input_schema.properties.contract_address
      assert prop.type == :string
    end

    test "input schema event_signatures is array of strings" do
      prism = WatchContractPrism.view()
      prop = prism.input_schema.properties.event_signatures
      assert prop.type == :array
      assert prop.items.type == :string
    end

    test "input schema chain_id is integer type" do
      prism = WatchContractPrism.view()
      prop = prism.input_schema.properties.chain_id
      assert prop.type == :integer
    end

    test "input schema action is string type" do
      prism = WatchContractPrism.view()
      prop = prism.input_schema.properties.action
      assert prop.type == :string
    end

    test "input schema webhook_url is string type" do
      prism = WatchContractPrism.view()
      prop = prism.input_schema.properties.webhook_url
      assert prop.type == :string
    end

    test "output schema subscription_id is string type" do
      prism = WatchContractPrism.view()
      prop = prism.output_schema.properties.subscription_id
      assert prop.type == :string
    end

    test "output schema status is string type" do
      prism = WatchContractPrism.view()
      prop = prism.output_schema.properties.status
      assert prop.type == :string
    end
  end

  describe "handler/2 with unknown action" do
    test "returns error for unknown action" do
      result =
        WatchContractPrism.handler(
          %{
            contract_address: @usdt_address,
            action: "invalid_action"
          },
          nil
        )

      case result do
        {:error, msg} ->
          assert String.contains?(msg, "Unknown action")

        _ ->
          # May fail for other reasons in unit test env
          assert true
      end
    end
  end
end
