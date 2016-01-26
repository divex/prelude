defmodule Prelude.Etude.Case do
  use Prelude.Etude.Node

  def exit({:case, line, value, clauses}, state) do
    {{:case, line, value, clauses}, state}
  end
end
