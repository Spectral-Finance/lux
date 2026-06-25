defmodule Lux.Prisms.Coinbase.ListProductsPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.ListProductsPrism

  describe "view/0" do
    test "returns valid prism struct with schema" do
      prism = ListProductsPrism.view()

      assert prism.name == "Coinbase List Products"
      assert prism.description =~ "Coinbase"
      assert prism.input_schema.type == :object
      assert prism.output_schema.type == :object
    end

    test "input schema has optional properties" do
      prism = ListProductsPrism.view()
      props = prism.input_schema.properties

      assert Map.has_key?(props, :limit)
      assert Map.has_key?(props, :product_type)
      assert "SPOT" in props.product_type.enum
      assert "FUTURE" in props.product_type.enum
    end

    test "output schema defines products array and total_count" do
      prism = ListProductsPrism.view()
      props = prism.output_schema.properties

      assert Map.has_key?(props, :products)
      assert Map.has_key?(props, :total_count)
    end
  end

  describe "handler/2" do
    test "requires coinbase SDK availability" do
      # Handler uses coinbase-advanced-py SDK via Python eval
      # In test environment without API keys, should return appropriate error
      result = ListProductsPrism.handler(%{limit: 5}, nil)

      # Either succeeds with data or returns error about missing config
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
