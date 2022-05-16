defmodule KNXex.DIB.IPConfig do
  @moduledoc """
  KNXnet/IP Data Information Block "IP Config" (and "Current IP Config").
  """

  alias KNXex

  @type t :: %__MODULE__{
          ip_address: :inet.ip4_address(),
          netmask: {byte(), byte(), byte(), byte()},
          gateway: :inet.ip4_address(),
          ip_capabilities: non_neg_integer(),
          ip_assignment_method: KNXex.PID.IPAssignmentMethod.method()
        }

  @fields [:ip_address, :netmask, :gateway, :ip_capabilities, :ip_assignment_method]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Converts a integer IP address (integer 32bit) to a four item tuple.
  """
  @spec integer_to_inet(integer()) :: :inet.ip4_address()
  def integer_to_inet(ip) do
    <<ip_a::size(8), ip_b::size(8), ip_c::size(8), ip_d::size(8)>> = <<ip::size(32)>>
    {ip_a, ip_b, ip_c, ip_d}
  end

  @doc """
  Converts a four item tuple IP address to a integer IP address (integer 32bit).
  """
  @spec inet_to_integer(:inet.ip4_address()) :: integer()
  def inet_to_integer({ip_a, ip_b, ip_c, ip_d}) do
    <<ip::size(32)>> = <<ip_a::size(8), ip_b::size(8), ip_c::size(8), ip_d::size(8)>>
    ip
  end
end
