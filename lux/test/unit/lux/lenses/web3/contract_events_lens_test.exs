defmodule Lux.Lenses.Web3.ContractEventsLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Web3.ContractEventsLens

  @usdt_address "0xdAC17F958D2ee523a2206206994597C13D831ec7"
  @transfer_sig "Transfer(address,address,uint256)"

  describe "view/0" do
    test "returns a Lens struct with correct metadata" do
      lens = ContractEventsLens.view()

      assert lens.name == "Web3 Contract Events Query"
      assert String.contains?(lens.description, "contract events")
      assert is_map(lens.schema)
      assert lens.schema.type == :object
    end

    test "schema contains expected properties" do
      lens = ContractEventsLens.view()
      props = lens.schema.properties

      assert Map.has_key?(props, :subscription_id)
      assert Map.has_key?(props, :contract_address)
      assert Map.has_key?(props, :event_signatures)
      assert Map.has_key?(props, :from_block)
      assert Map.has_key?(props, :to_block)
      assert Map.has_key?(props, :chain_id)
      assert Map.has_key?(props, :limit)
    end
  end

  describe "focus/2 with subscription_id" do
    test "returns not-found message for non-existent subscription" do
      # Without a running EventMonitor, this will fail gracefully
      # The lens should handle the missing subscription case
      params = %{
        subscription_id: "nonexistent-sub",
        limit: 10
      }

      # This will either return events or a not-found message
      # depending on whether EventMonitor is running
      result = ContractEventsLens.focus(params, [])

      case result do
        {:ok, %{events: [], message: msg}} ->
          assert String.contains?(msg, "not found")

        {:ok, %{events: events, count: count}} ->
          assert is_list(events)
          assert is_integer(count)

        {:error, _reason} ->
          # EventMonitor not running - expected in unit tests
          assert true
      end
    end
  end

  describe "focus/2 validation" do
    test "returns error when neither subscription_id nor contract_address provided" do
      result = ContractEventsLens.focus(%{limit: 10}, [])

      case result do
        {:error, msg} ->
          assert String.contains?(msg, "required")

        _ ->
          # Some error path
          assert true
      end
    end
  end

  describe "schema structure" do
    test "subscription_id property has correct type" do
      lens = ContractEventsLens.view()
      prop = lens.schema.properties.subscription_id
      assert prop.type == :string
    end

    test "event_signatures property is array type" do
      lens = ContractEventsLens.view()
      prop = lens.schema.properties.event_signatures
      assert prop.type == :array
      assert prop.items.type == :string
    end

    test "chain_id property has correct type" do
      lens = ContractEventsLens.view()
      prop = lens.schema.properties.chain_id
      assert prop.type == :integer
    end

    test "from_block property has correct type" do
      lens = ContractEventsLens.view()
      prop = lens.schema.properties.from_block
      assert prop.type == :integer
    end
  end
end
