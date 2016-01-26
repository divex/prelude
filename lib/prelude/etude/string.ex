defmodule Prelude.Etude.String do
  use Prelude.Etude.Node

  def exit({:string, line, value}, state) do
    {{:string, line, value}, state}
  end
end
