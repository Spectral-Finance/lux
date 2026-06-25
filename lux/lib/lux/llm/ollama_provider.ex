defmodule Lux.LLM.OllamaProvider do
  @moduledoc "Local LLM via Ollama bounty #96."
  @default_ep "http://localhost:11434"
  @spec init(String.t()|nil) :: {:ok,String.t()}|{:error,term()}
  def init(ep), do: case list_models(ep) do {:ok,[m|_] } -> {:ok,m};_->{:error,"Ollama unreachable"} end
  @spec complete(String.t(),String.t(),map()) :: {:ok,String.t()}|{:error,term()}
  def complete(model,prompt,opts) do
    ep=Map.get(opts,:ep,@default_ep)
    body=Jason.encode!(%{model:model,prompt:prompt,stream:false,temperature:Map.get(opts,:temperature,0.7)})
    case :httpc.request(to_charlist(ep+"/api/generate"),[],[],[body:body,content_type:"application/json"]) do
      {:ok,{{_,200,_},_,resp}}->case Jason.decode(resp) do {:ok,%{"response"=>a}}->{:ok,a};_->{:error,"decode"} end
      {:error,r}->{:error,"Request failed: "+inspect(r)}
    end
  end
  @spec list_models(String.t()|nil) :: {:ok,[String.t()]}|{:error,term()}
  def list_models(ep) do
    case :httpc.request(to_charlist(ep+"/api/tags"),[],[],[]) do
      {:ok,{{_,200,_},_,body}}->case Jason.decode(body) do {:ok,%{"models"=>ms}}->{:ok,Enum.map(ms,&to_string(&1["name"]))};_->{:error,"bad"} end
      _->{:error,"list fail"}
    end
  end
  @spec benchmark(String.t(),String.t()|nil) :: {:ok,map()}|{:error,term()}
  def benchmark(model,ep) do
    prompts=["Explain quantum computing.","Write a haiku about blockchain."]
    res=Enum.map(prompts,fn p->
      st=System.monotonic_time(:millisecond);complete(model,p,ep:ep);el=System.monotonic_time(:millisecond)-st
      %{prompt_length:byte_size(p),elapsed_ms:el}
    end)
    avg=Enum.map(res,& &1.elapsed_ms)|>Enum.sum()/length(res)
    {:ok,%{model:model,tests_run:length(res),average_latency_ms:Float.round(avg,2),details:res}}
  end
end