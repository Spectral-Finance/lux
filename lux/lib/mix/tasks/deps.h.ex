defmodule Mix.Tasks.Deps.H do
  @moduledoc """
  Quick helper to read dependency documentation from the command line and print it to the terminal.
  You might want to add this to your .cursorrules file

  Examples:
  mix deps.h Req.Request
  mix deps.h Req.Request.append_error_steps/2
  """

  def run(args) do
    # runs mix run --eval 'require IEx.Helpers; IEx.Helpers.h(Req)'
    {result, 0} =
      System.cmd("mix", ["run", "--eval", "require IEx.Helpers; IEx.Helpers.h(#{args})"])

    result
    |> String.split("\n")
    |> Enum.each(&IO.puts/1)
  end
end
