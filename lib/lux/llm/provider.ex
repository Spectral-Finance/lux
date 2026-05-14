# In a LuxApp handler or Agent module
alias Lux.LLM.Client

def handle_request(prompt) do
  # Configuration: Requesting a specific model, but allowing fallback
  options = %{
    model: "gpt-4o", 
    temperature: 0.7
  }

  case Client.generate(prompt, options) do
    {:ok, %{content: content}} ->
      {:ok, "Successfully generated content: #{content}"}
    {:error, reason} ->
      {:error, "LLM Service Failure: #{reason}"}
  end
end