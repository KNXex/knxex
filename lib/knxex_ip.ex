defmodule KNXexIP do
  @moduledoc """
  Documentation for `KNXexIP`.
  """

  # Same as Kernel.struct!(), but you can use it in pipelines.
  # With extra safety that if the enum is a struct, it simply gets returned (no struct type check).
  @doc false
  @spec to_struct!(Enumerable.t(), atom | module) :: term()
  defmacro to_struct!(enum, struct) do
    quote generated: true do
      case is_struct(unquote(enum)) do
        true -> unquote(enum)
        false -> Kernel.struct!(unquote(struct), unquote(enum))
      end
    end
  end
end
