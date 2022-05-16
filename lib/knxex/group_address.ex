defmodule KNXex.GroupAddress do
  @moduledoc """
  KNX group address.
  """

  @typedoc """
  Represents a KNX group address.
  """
  @type t :: %__MODULE__{
          main: non_neg_integer(),
          middle: non_neg_integer(),
          sub: non_neg_integer()
        }

  @enforce_keys [:main, :middle, :sub]
  defstruct [:main, :middle, :sub]

  @doc """
  Creates a `GroupAddress` struct from the given `main`, `middle` and `sub` group addresses parts.
  """
  @spec make(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def make(main, middle, sub) when is_integer(main) and is_integer(middle) and is_integer(sub) do
    %__MODULE__{
      main: main,
      middle: middle,
      sub: sub
    }
  end

  @doc """
  Parses a group address from a string into a `GroupAddress` struct.
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, :invalid_binary}
  def from_string(group) when is_binary(group) do
    case Regex.scan(~r"(\d+)/(\d+)/(\d+)", group) do
      [[_full, main, middle, sub]] ->
        {:ok,
         %__MODULE__{
           main: String.to_integer(main),
           middle: String.to_integer(middle),
           sub: String.to_integer(sub)
         }}

      _invalid ->
        {:error, :invalid_binary}
    end
  end

  @doc """
  Returns the group address as a string.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = group) do
    "#{group.main}/#{group.middle}/#{group.sub}"
  end

  @doc """
  Parses the raw group address (16bit integer) into a `GroupAddress` struct.
  """
  @spec from_raw_address(non_neg_integer()) :: t()
  def from_raw_address(address) do
    <<main::size(5), middle::size(3), sub::size(8)>> = <<address::size(16)>>

    %__MODULE__{
      main: main,
      middle: middle,
      sub: sub
    }
  end

  @doc """
  Returns the raw group address (16bit integer).
  """
  @spec to_raw_address(t()) :: non_neg_integer()
  def to_raw_address(%__MODULE__{} = group) do
    <<address::size(16)>> = <<group.main::size(5), group.middle::size(3), group.sub::size(8)>>

    address
  end

  defimpl String.Chars do
    @moduledoc false

    @doc """
    Provides a `String.Chars` implementation for `GroupAddress`.
    """
    @spec to_string(KNXex.GroupAddress.t()) :: binary()
    defdelegate to_string(t), to: KNXex.GroupAddress
  end
end
