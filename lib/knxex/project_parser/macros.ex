defmodule KNXex.ProjectParser.Macros do
  @moduledoc false

  @doc """
  Turns a XML value (charlist) into a bool.
  """
  @spec xml_value_to_bool(charlist()) :: Macro.t()
  defmacro xml_value_to_bool(value) do
    quote do
      unquote(value) == 'true'
    end
  end

  @doc """
  Turns a XML value (charlist) into a `NaiveDateTime`.
  """
  @spec xml_value_to_ndt(charlist()) :: Macro.t()
  defmacro xml_value_to_ndt(value) do
    quote do
      NaiveDateTime.from_iso8601!(:binary.list_to_bin(unquote(value)))
    end
  end

  @doc """
  Turns a XML value (charlist) into an integer.
  """
  @spec xml_value_to_int(charlist()) :: Macro.t()
  defmacro xml_value_to_int(value) do
    quote do
      String.to_integer(:binary.list_to_bin(unquote(value)))
    end
  end

  @doc """
  Turns a XML value (charlist) into a string (unicode-aware).
  This macro also inserts a call to `String.trim/1` to remove any whitespace.
  """
  @spec xml_value_to_string(charlist()) :: Macro.t()
  defmacro xml_value_to_string(value) do
    quote do
      String.trim(:unicode.characters_to_binary(unquote(value)))
    end
  end
end
