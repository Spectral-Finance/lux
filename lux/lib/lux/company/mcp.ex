defmodule Lux.Company.MCP do
  @moduledoc """
  MCP (Model Context Protocol) client for Syntax Company
  """

  alias Lux.Config
  alias Lux.MCP.Tool

  def list_tools(params \\ []) do
    with {:ok, %{"tools" => tools}} <- call("tools/list", params),
         tools <- Enum.map(tools, fn tool -> Tool.from_map(tool) end) do
      {:ok, tools}
    else
      _ ->
        {:ok, []}
    end
  end

  def call(method, params) do
    Req.post(
      base_url: Config.syntax_agent_api_url(),
      url: "/mcp/companies/:company_contract_address",
      json: %{
        jsonrpc: "2.0",
        id: Lux.UUID.generate(),
        method: method,
        params: params
      },
      path_params: %{
        company_contract_address: Config.syntax_company_contract_address()
      },
      headers: [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{Config.syntax_agent_api_key()}"}
      ]
    )
    |> case do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %{status: status, body: %{"errors" => errors}}} ->
        {:error, %{status: status, errors: errors}}

      {:error, error} ->
        {:error, "Error calling MCP API: #{inspect(error)}"}
    end
  end
end
