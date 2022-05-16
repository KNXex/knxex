defmodule KNXex.IndividualAddress do
  @moduledoc """
  KNX individual address (also known as physical address).
  """

  @typedoc """
  Represents a KNX individual address.
  """
  @type t :: %__MODULE__{
          area: non_neg_integer(),
          line: non_neg_integer(),
          device: non_neg_integer()
        }

  @enforce_keys [:area, :line, :device]
  defstruct [:area, :line, :device]

  @doc """
  Creates a `IndividualAddress` struct from the given `area`, `line` and `device` individual addresses parts.
  """
  @spec make(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def make(area, line, device)
      when is_integer(area) and is_integer(line) and is_integer(device) do
    %__MODULE__{
      area: area,
      line: line,
      device: device
    }
  end

  @doc """
  Parses a individual address from a string into a `IndividualAddress` struct.
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, :invalid_binary}
  def from_string(individual) when is_binary(individual) do
    case Regex.scan(~r"(\d+)\.(\d+)\.(\d+)", individual) do
      [[_full, area, line, device]] ->
        {:ok,
         %__MODULE__{
           area: String.to_integer(area),
           line: String.to_integer(line),
           device: String.to_integer(device)
         }}

      _invalid ->
        {:error, :invalid_binary}
    end
  end

  @doc """
  Returns the individual address as a string.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = individual) do
    "#{individual.area}.#{individual.line}.#{individual.device}"
  end

  @doc """
  Parses the raw individual address (16bit integer) into a `IndividualAddress` struct.
  """
  @spec from_raw_address(non_neg_integer()) :: t()
  def from_raw_address(address) do
    <<area::size(4), line::size(4), device::size(8)>> = <<address::size(16)>>

    %__MODULE__{
      area: area,
      line: line,
      device: device
    }
  end

  @doc """
  Returns the raw individual address (16bit integer).
  """
  @spec to_raw_address(t()) :: non_neg_integer()
  def to_raw_address(%__MODULE__{} = individual) do
    <<address::size(16)>> =
      <<individual.area::size(4), individual.line::size(4), individual.device::size(8)>>

    address
  end

  defimpl String.Chars do
    @moduledoc false

    @doc """
    Provides a `String.Chars` implementation for `IndividualAddress`.
    """
    @spec to_string(KNXex.IndividualAddress.t()) :: binary()
    defdelegate to_string(t), to: KNXex.IndividualAddress
  end
end
