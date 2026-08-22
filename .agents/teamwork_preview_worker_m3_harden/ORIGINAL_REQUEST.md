## 2026-07-25T22:58:19Z
Enhance `/home/Konor1743/Operacion Dolar/lux/lux/lib/lux/llm/open_router.ex` (and mirrored copies) with robust edge-case handling based on Challenger findings:

1. **Header Name & Truthiness Guard**:
   In `build_headers/1`, ensure empty strings `""` do not shadow non-empty configuration keys:
   ```elixir
   site_url =
     cond do
       is_binary(config.http_referer) and config.http_referer != "" -> Lux.Config.resolve(config.http_referer)
       is_binary(config.site_url) and config.site_url != "" -> Lux.Config.resolve(config.site_url)
       true -> nil
     end

   site_name =
     cond do
       is_binary(config.openrouter_title) and config.openrouter_title != "" -> Lux.Config.resolve(config.openrouter_title)
       is_binary(config.site_name) and config.site_name != "" -> Lux.Config.resolve(config.site_name)
       true -> nil
     end
   ```

2. **Tool Name Extraction Guard**:
   In `tool_to_function/1` for Beam, Prism, Lens, check string non-emptiness so `module_name: ""` does not produce empty function name `""`:
   ```elixir
   name =
     cond do
       is_binary(struct.module_name) and struct.module_name != "" -> struct.module_name
       is_binary(struct.name) and struct.name != "" -> struct.name
       true -> "unnamed_tool"
     end
   ```

3. **Content Parsing & ResponseSignal Schema Compatibility**:
   In `parse_content/1`, ensure raw text content parses cleanly so that `ResponseSignal` schema validation (which requires `content` to be an object or null) always succeeds:
   ```elixir
   def parse_content(content) when is_binary(content) do
     case Jason.decode(content) do
       {:ok, structured_output} ->
         {:ok, structured_output}

       {:error, _} ->
         {:ok, %{"text" => content}}
     end
   end

   def parse_content(nil), do: {:ok, nil}
   def parse_content(other), do: {:ok, other}
   ```

4. **Usage Token Extraction Null Safety**:
   Ensure `"usage"` being missing or `nil` in JSON body falls back to zero counts map:
   ```elixir
   usage =
     case body["usage"] do
       %{} = u -> u
       _ -> %{"prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0}
     end
   ```

5. **Tool Execution Exception Safety**:
   In `execute_tool_calls` / `execute_tool_call`, decode JSON args safely and rescue runtime exceptions to prevent crashing the caller process:
   ```elixir
   def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
     case Jason.decode(args) do
       {:ok, decoded_args} ->
         try do
           execute_tool(tool_name, decoded_args, nil)
         rescue
           e -> {:error, "Error executing tool #{tool_name}: #{inspect(e)}"}
         end

       {:error, error} ->
         {:error, "Failed to decode arguments for tool #{tool_name}: #{inspect(error)}"}
     end
   end
   ```

6. Update test files (`lux/test/unit/lux/llm/open_router_test.exs` and relative copies) with tests covering plain-text content responses, empty string header fallbacks, tool exception rescue, and null usage maps.
7. Deliver `changes.md` and `handoff.md` in `/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_worker_m3_harden/`. Send a message to parent when finished.
