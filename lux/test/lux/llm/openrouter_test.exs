defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.OpenRouter

  test "builds OpenRouter request bodies with routing options" do
    body =
      OpenRouter.build_request_body(
        "openai/gpt-4o-mini",
        [%{role: "user", content: "hello"}],
        temperature: 0.2,
        provider: %{sort: "price", allow_fallbacks: true, quantizations: ["bf16"]},
        transforms: ["middle-out"],
        cache_control: %{type: "ephemeral"}
      )

    assert body["model"] == "openai/gpt-4o-mini"
    assert body["messages"] == [%{"role" => "user", "content" => "hello"}]
    assert body["temperature"] == 0.2
    assert body["provider"] == %{
             "sort" => "price",
             "allow_fallbacks" => true,
             "quantizations" => ["bf16"]
           }

    assert body["transforms"] == ["middle-out"]
    assert body["cache_control"] == %{"type" => "ephemeral"}
  end

  test "supports json response shortcuts" do
    assert %{"response_format" => %{"type" => "json_object"}} =
             OpenRouter.build_request_body("openai/gpt-4o-mini", [], json_response: true)

    assert %{"response_format" => %{"type" => "json_schema", "json_schema" => schema}} =
             OpenRouter.build_request_body("openai/gpt-4o-mini", [],
               json_schema: %{name: "answer", schema: %{type: "object"}}
             )

    assert schema == %{"name" => "answer", "schema" => %{"type" => "object"}}
  end

  test "estimates known model costs from usage" do
    cost =
      OpenRouter.calculate_cost(
        %{"prompt_tokens" => 1_000_000, "completion_tokens" => 500_000},
        "openai/gpt-4o-mini"
      )

    assert cost["prompt_tokens_cost"] == 0.15
    assert cost["completion_tokens_cost"] == 0.3
    assert cost["total_cost"] == 0.45
    assert cost["currency"] == "USD"
    assert cost["source"] == "estimated"
  end

  test "uses OpenRouter reported cost when available" do
    assert %{"total_cost" => 0.0123, "source" => "openrouter"} =
             OpenRouter.calculate_cost(%{"cost" => 0.0123}, "unknown/model")
  end

  test "returns authentication error without api key" do
    original = System.get_env("OPENROUTER_API_KEY")
    System.delete_env("OPENROUTER_API_KEY")

    try do
      assert {:error, %OpenRouter.Error{type: :authentication}} = OpenRouter.chat([])
    after
      if original, do: System.put_env("OPENROUTER_API_KEY", original)
    end
  end

  test "annotates successful responses and supports local fallback models" do
    parent = self()

    http_client = fn :post, request, _http_options, _options ->
      send(parent, {:request, request})
      {_url, _headers, _content_type, body} = request
      decoded = Jason.decode!(body)

      case decoded["model"] do
        "first/model" ->
          {:ok, {{'HTTP/1.1', 429, 'Too Many Requests'}, [], Jason.encode!(%{error: %{message: "rate limited"}})}}

        "second/model" ->
          {:ok,
           {{'HTTP/1.1', 200, 'OK'}, [],
            Jason.encode!(%{
              id: "chatcmpl-test",
              model: "second/model",
              choices: [],
              usage: %{prompt_tokens: 10, completion_tokens: 5}
            })}}
      end
    end

    assert {:ok, response} =
             OpenRouter.chat([%{role: "user", content: "hello"}],
               api_key: "test-key",
               models: ["first/model", "second/model"],
               retries: 0,
               http_client: http_client
             )

    assert response["lux"]["provider"] == "openrouter"
    assert response["lux"]["requested_model"] == "second/model"
    assert response["lux"]["attempted_models"] == ["first/model", "second/model"]

    assert_receive {:request, _first_request}
    assert_receive {:request, _second_request}
  end
end
