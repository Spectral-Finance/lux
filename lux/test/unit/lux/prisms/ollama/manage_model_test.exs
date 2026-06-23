defmodule Lux.Prisms.Ollama.ManageModelTest do
  @moduledoc """
  Test suite for the ManageModel module.
  These tests verify the prism's ability to:
  - Pull models from the Ollama library
  - Delete models from the Ollama instance
  - Handle Ollama API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Ollama.ManageModel

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2 - pull" do
    test "successfully pulls a model" do
      Req.Test.expect(OllamaManageModelMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "llama3"
        assert decoded["stream"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "success"}))
      end)

      assert {:ok,
              %{
                success: true,
                action: "pull",
                model_name: "llama3",
                status: "success"
              }} =
               ManageModel.handler(
                 %{
                   action: "pull",
                   model_name: "llama3",
                   plug: {Req.Test, OllamaManageModelMock}
                 },
                 @agent_ctx
               )
    end

    test "handles pull error" do
      Req.Test.expect(OllamaManageModelMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          404,
          Jason.encode!(%{"error" => "model 'nonexistent' not found"})
        )
      end)

      assert {:error, {404, "model 'nonexistent' not found"}} =
               ManageModel.handler(
                 %{
                   action: "pull",
                   model_name: "nonexistent",
                   plug: {Req.Test, OllamaManageModelMock}
                 },
                 @agent_ctx
               )
    end
  end

  describe "handler/2 - delete" do
    test "successfully deletes a model" do
      Req.Test.expect(OllamaManageModelMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/delete"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "llama3"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok,
              %{
                success: true,
                action: "delete",
                model_name: "llama3",
                status: "success"
              }} =
               ManageModel.handler(
                 %{
                   action: "delete",
                   model_name: "llama3",
                   plug: {Req.Test, OllamaManageModelMock}
                 },
                 @agent_ctx
               )
    end

    test "handles delete error" do
      Req.Test.expect(OllamaManageModelMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/delete"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          404,
          Jason.encode!(%{"error" => "model 'nonexistent' not found"})
        )
      end)

      assert {:error, {404, "model 'nonexistent' not found"}} =
               ManageModel.handler(
                 %{
                   action: "delete",
                   model_name: "nonexistent",
                   plug: {Req.Test, OllamaManageModelMock}
                 },
                 @agent_ctx
               )
    end
  end

  describe "handler/2 - validation" do
    test "rejects invalid action" do
      assert {:error, "Invalid action: \"invalid\"" <> _} =
               ManageModel.handler(
                 %{
                   action: "invalid",
                   model_name: "llama3"
                 },
                 @agent_ctx
               )
    end

    test "rejects missing model_name" do
      assert {:error, "Missing or invalid model_name"} =
               ManageModel.handler(
                 %{
                   action: "pull"
                 },
                 @agent_ctx
               )
    end

    test "rejects missing action" do
      assert {:error, "Missing required parameter: action"} =
               ManageModel.handler(
                 %{
                   model_name: "llama3"
                 },
                 @agent_ctx
               )
    end
  end
end
