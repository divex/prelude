defmodule Prelude.ErlSyntax do
  defmacro erl(string, line \\ -1) do
    sigil(string, line, __CALLER__)
  end

  defp sigil(string, line, caller) do
    {string, _} = Code.eval_quoted(string, [], caller)
    case parse_expr(string) do
      {:ok, [tree]} ->
        apply_unquote(tree, line)
      {:ok, tree} ->
        apply_unquote({:block, -1, tree}, line)
    end
  end

  def parse(s) do
    {:ok, tokens, _} = s |> to_string() |> to_char_list |> :erl_scan.string()

    {forms, _} = Enum.reduce(tokens, {[], []}, fn
      ({:dot, _} = dot, {forms, acc}) ->
        {:ok, form} = :erl_parse.parse_form(:lists.reverse([dot | acc]))
        {[form | forms], []}
      (token, {forms, acc}) ->
        {forms, [token | acc]}
    end)

    forms
    |> Enum.reverse()
  end

  def parse_expr(s) do
    {:ok, tokens, _} = s |> String.to_char_list |> :erl_scan.string()
    tokens = tokens |> Enum.map(&put_elem(&1, 1, -1))
    :erl_parse.parse_exprs(tokens ++ [dot: -1])
  end

  def escape(value, line \\ -1)
  def escape(value, line) when is_atom(value) do
    {:atom, line, value}
  end
  def escape(value, line) when is_integer(value) do
    {:integer, line, value}
  end
  def escape(value, line) when is_binary(value) do
    {:bin, line, [{:bin_element, line, {:string, line, to_char_list(value)}, :default, :default}]}
  end
  def escape([], line) do
    {:nil, line}
  end
  def escape([argument | arguments], line) do
    {:cons, line, escape(argument, line), escape(arguments, line)}
  end
  def escape(map, line) when is_map(map) do
    {:map, line,
     :maps.fold(fn(k, v, acc) ->
       kv = {:map_field_assoc, line, escape(k, line), escape(v, line)}
       [kv | acc]
     end, [], map)}
  end
  def escape(tuple, line) when is_tuple(tuple) do
    items = tuple |> :erlang.tuple_to_list() |> Enum.map(&escape(&1, line))
    {:tuple, line, items}
  end

  defp apply_unquote(tree, line) do
    tree
    |> Macro.escape()
    |> Macro.postwalk(fn
      ({:{}, _,
        [:call, _, {:{}, _, [:atom, _, :unquote]},
         [{:{}, _, [:atom, _, name]}]]}) ->
        Macro.var(name, nil)
      ({:{}, l, [name, prev | rest]}) when is_integer(prev) ->
        {:{}, l, [name, line | rest]}
      (other) ->
        other
    end)
  end

  def prewalk(forms, acc, enter) do
    traverse(forms, acc, enter, fn(node, acc) -> {node, acc} end)
  end

  def postwalk(forms, acc, exit) do
    traverse(forms, acc, fn(node, acc) -> {node, acc} end, exit)
  end

  def traverse(forms, acc, enter, exit) when is_list(forms) do
    Enum.map_reduce(forms, acc, &traverse(&1, &2, enter, exit))
  end
  def traverse({:tree, type, _, _} = tree, acc, _enter, _exit) when type in [:class_qualifier, :conjunction, :disjunction, :operator, :size_qualifier] do
    {tree, acc}
  end
  def traverse({:cons, _, _, _} = node, acc, enter, exit) do
    {{:cons, line, value, tail}, acc} = enter.(node, acc)
    {value, acc} = traverse(value, acc, enter, exit)
    {tail, acc} = traverse(tail, acc, enter, exit)
    exit.({:cons, line, value, tail}, acc)
  end
  def traverse({type, _, _, _, _} = node, acc, enter, exit) when type in [:clause, :function] do
    {{type, line, name, arity, clauses}, acc} = enter.(node, acc)
    {clauses, acc} = traverse(clauses, acc, enter, exit)
    exit.({type, line, name, arity, clauses}, acc)
  end
  def traverse({:case, _, _, _} = node, acc, enter, exit) do
    {{type, line, value, clauses}, acc} = enter.(node, acc)
    {value, acc} = traverse(value, acc, enter, exit)
    {clauses, acc} = traverse(clauses, acc, enter, exit)
    exit.({type, line, value, clauses}, acc)
  end
  def traverse({:fun, _, clauses} = node, acc, enter, exit) do
    {{type, line, {:clauses, clauses}}, acc} = enter.(node, acc)
    {clauses, acc} = traverse(clauses, acc, enter, exit)
    exit.({type, line, {:clauses, clauses}}, acc)
  end
  def traverse({:match, _, _, _} = node, acc, enter, exit) do
    {{:match, line, lhs, rhs}, acc} = enter.(node, acc)
    {rhs, acc} = traverse(rhs, acc, enter, exit)
    exit.({:match, line, lhs, rhs}, acc)
  end
  def traverse({:bin_element, _, _, _, _} = node, acc, enter, exit) do
    {{:bin_element, line, value, size, opts}, acc} = enter.(node, acc)

    {value, acc} = traverse(value, acc, enter, exit)

    {size, acc} = if is_atom(size) do
      {size, acc}
    else
      traverse(size, acc, enter, exit)
    end

    exit.({:bin_element, line, value, size, opts}, acc)
  end
  def traverse(form, acc, enter, exit) do
    {form, acc} = enter.(form, acc)
    {form, acc} = case :erl_syntax.subtrees(form) do
      [] ->
        {revert_form(form), acc}
      subtrees ->
        {t, acc} = traverse(subtrees, acc, enter, exit)
        {:erl_syntax.update_tree(form, t) |> revert_form(), acc}
    end
    exit.(form, acc)
  end

  defp revert_form(f) do
    case :erl_syntax.revert(f) do
      {:attribute,l,a,tree} when elem(tree, 0) == :tree ->
        {:attribute,l,a,:erl_syntax.revert(tree)}
      res ->
        res
    end
  end
end
