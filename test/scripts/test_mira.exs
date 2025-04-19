alias Lux.LLM.Mira

# Configure the Mira Network client
config = %{
  api_key: System.get_env("MIRA_API_KEY"),
  model: "llama-3.1-8b-instruct",
  temperature: 0.7,
  stream: false
}

# Test a simple completion
case Mira.call("What is the capital of France?", [], config) do
  {:ok, response} ->
    IO.puts("Success! Response:")
    IO.inspect(response, label: "Response", pretty: true)

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end 
