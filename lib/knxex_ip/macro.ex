defmodule KNXexIP.Macro do
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
    quote do
      def assert_name(unquote(type), unquote(name)), do: unquote(name)
      def by_name(unquote(type), unquote(name)), do: unquote(value)
      def by_value(unquote(type), unquote(value)), do: unquote(name)

      defmacro macro_assert_name(unquote(type), unquote(name)), do: unquote(name)
      defmacro macro_by_name(unquote(type), unquote(name)), do: unquote(value)
      defmacro macro_by_value(unquote(type), unquote(value)), do: unquote(name)

      @constants {unquote(type), unquote(name), unquote(value)}
    end
  end
end
