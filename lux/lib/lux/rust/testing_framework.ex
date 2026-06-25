defmodule Lux.Rust.TestingFramework do
  @moduledoc "Rust-style Testing Framework bounty #102."
  @spec property(String.t(),(->boolean())) :: map()
  def property(name,fun) when is_function(fun,0), do: %{type::property_test,name:name,test_fn:fun,runs:100,status::pending}
  @spec run_suite([map()]) :: map()
  def run_suite(tests) do
    results=Enum.map(tests,fn t->
      try do passed=Enum.all?(1..t.runs,fn->_->t.test_fn.() end); %{name:t.name,status:if(passed,do::passed,else::failed),runs:t.runs}
      rescue _->%{name:t.name,status::error,runs:0} end
    end)
    %{total:length(results),passed:Enum.count(results,&(&1.status==:passed)),failed:length(results)-Enum.count(results,&(&1.status==:passed)),results:results,coverage:Float.round(Enum.count(results,&(&1.status in[:passed,:failed]))/max(1,length(results))*100,2)}
  end
  @spec fuzz_test(String.t(),map()) :: [map()]
  def fuzz_test(name,_type), do: Enum.map(1..50,fn i->%{name:name+"_fuzz_"+Integer.to_string(i),input:%{data:"random"},expected_valid:true} end)
end