defmodule Lux.LensTest do
  use ExUnit.Case, async: false

  setup do
    Req.Test.start_link()
    :ok
  end

  describe "When we `use` a Lens" do
    test "supports focus with input params" do
      Req.Test.expect(:get, "http://api.weatherapi.com/v1/current.json", fn _request ->
        {:ok, %{status: 200, body: %{"temp" => 20}}}
      end)

      assert {:ok, %{"temp" => 20}} = TestLens.focus(%{city: "London"})
    end

    test "supports custom after_focus transformation" do
      Req.Test.expect(:get, "http://api.weatherapi.com/v1/current.json", fn _request ->
        {:ok, %{status: 200, body: %{"temp" => 25}}}
      end)

      assert {:ok, %{temperature: 25, unit: "C"}} =
               TransformLens.focus(%{}, with_after_focus: true)
    end

    test "works without after_focus function" do
      Req.Test.expect(:get, "http://api.weatherapi.com/v1/current.json", fn _request ->
        {:ok, %{status: 200, body: %{"temp" => 25}}}
      end)

      assert {:ok, %{"temp" => 25}} = BasicLens.focus(%{}, with_after_focus: false)
    end
  end

  test "focus returns the body on status 200" do
    Req.Test.expect(:get, "http://api.weatherapi.com/v1/current.json", fn _request ->
      {:ok, %{status: 200, body: %{"celcius" => -15}}}
    end)

    lens = %Lux.Lens{
      url: "http://api.weatherapi.com/v1/current.json",
      method: :get,
      headers: [{"Content-Type", "application/json"}]
    }

    assert {:ok, %{"celcius" => -15}} = Lux.Lens.focus(lens)
  end
end
