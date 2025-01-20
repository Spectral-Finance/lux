defmodule Lux.LLM.OpenAI do
  @moduledoc """
  OpenAI LLM implementation.
  """

  alias Lux.Signal

  @default_model "gpt-4-turbo-preview"

  @doc """
  Makes a call to the OpenAI API.
  """
  def call(prompt, tools \\ [], config: config) do
    config = Keyword.put_new(config, :model, @default_model)

    messages = [%{role: "user", content: prompt}]

    body =
      %{
        model: config[:model],
        messages: messages,
        temperature: 0.7
      }
      |> maybe_add_tools(tools)

    case Req.post("https://api.openai.com/v1/chat/completions",
           headers: [
             {"Authorization", "Bearer #{config[:api_key]}"},
             {"Content-Type", "application/json"}
           ],
           json: body
         ) do
      {:ok,
       %{
         status: 200,
         body: %{"choices" => [%{"message" => message, "finish_reason" => finish_reason} | _]}
       }} ->
        {:ok,
         %Signal{
           schema_id: Lux.LLM.ResponseSchema,
           payload: %{
             content: message["content"],
             tool_calls: message["tool_calls"],
             model: config[:model],
             finish_reason: finish_reason
           }
         }}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, "API error (#{status}): #{message}"}

      {:error, %{reason: reason}} ->
        {:error, "Failed to connect to OpenAI API: #{inspect(reason)}"}
    end
  end

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools) do
    Map.put(body, :tools, tools)
  end
end
