defmodule KNXex.Macro do
  @moduledoc false

  # This has been verbatim copied from KNXnetIP.Frame.Constant.Macro
  # and slightly adjusted (added the defmacro)

  defmacro __before_compile__(_env) do
    quote location: :keep do
      def by_name(_name, _value), do: nil
      def by_value(_name, _value), do: nil
    end
  end

  defmacro defconstant(type, name, value) do
    # All functions and macros are defined as without docs,
    # as the docs would make no sense without the pattern matched
    # function headers
    quote do
      @doc false
      def assert_name(unquote(type), unquote(name)), do: unquote(name)

      @doc false
      def by_name(unquote(type), unquote(name)), do: unquote(value)

      @doc false
      def by_value(unquote(type), unquote(value)), do: unquote(name)

      @doc false
      defmacro macro_assert_name(unquote(type), unquote(name)), do: unquote(name)

      @doc false
      defmacro macro_by_name(unquote(type), unquote(name)), do: unquote(value)

      @doc false
      defmacro macro_by_value(unquote(type), unquote(value)), do: unquote(name)

      @constants {unquote(type), unquote(name), unquote(value)}
    end
  end
end
