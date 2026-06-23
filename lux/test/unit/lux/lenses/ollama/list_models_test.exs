defmodule Lux.Lenses.Ollama.ListModelsTest do
  @moduledoc """
  Test suite for the ListModels module.
  These tests verify the lens's ability to:
  - List models from an Ollama instance
  - Handle Ollama API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Ollama.ListModels

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists models" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "models" => [
              %{
                "name" => "llama3:latest",
                "size" => 4_661_224_676,
                "modified_at" => "2024-03-28T12:00:00Z",
                "digest" => "abc123def456",
                "details" => %{
                  "format" => "gguf",
                  "family" => "llama",
                  "parameter_size" => "8B"
                }
              },
              %{
                "name" => "mistral:latest",
                "size" => 4_109_865_159,
                "modified_at" => "2024-03-27T10:00:00Z",
                "digest" => "def456abc789",
                "details" => %{
                  "format" => "gguf",
                  "family" => "mistral",
                  "parameter_size" => "7B"
                }
              }
            ]
          })
        )
      end)

      assert {:ok,
              [
                %{
                  name: "llama3:latest",
                  size: 4_661_224_676,
                  modified_at: "2024-03-28T12:00:00Z",
                  digest: "abc123def456",
                  details: %{
                    "format" => "gguf",
                    "family" => "llama",
                    "parameter_size" => "8B"
                  }
                },
                %{
                  name: "mistral:latest",
                  size: 4_109_865_159,
                  modified_at: "2024-03-27T10:00:00Z",
                  digest: "def456abc789",
                  details: %{
                    "format" => "gguf",
                    "family" => "mistral",
                    "parameter_size" => "7B"
                  }
                }
              ]} = ListModels.focus(%{}, %{})
    end

    test "handles Ollama API error" do
      Req.Test.stub(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          500,
          Jason.encode!(%{
            "error" => "internal server error"
          })
        )
      end)

      assert {:error, _} = ListModels.focus(%{}, %{})
    end

    test "handles empty models list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"models" => []}))
      end)

      assert {:ok, []} = ListModels.focus(%{}, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = ListModels.view()
      assert lens.schema.properties == %{}
      assert lens.schema.required == []
    end
  end
end
