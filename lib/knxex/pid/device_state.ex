defmodule KNXex.PID.DeviceState do
  @moduledoc """
  KNXnet/IP Parameter Object "Device State".
  """

  import KNXex.Macro

  defconstant(:meta, :pid, 69)
  defconstant(:meta, :name, "KNXnet/IP Device State")

  defconstant(:bits, :knx_fault, 0)
  defconstant(:bits, :ip_fault, 1)

  # Checks if the value is a struct or an int, and checks if the bit is set (bit as integer value, i.e. bit 0 = 1).
  @spec check_bit(integer(), integer()) :: Macro.t()
  defguardp check_bit(t, value)
            when is_integer(t) and :erlang.band(t, value) > 0

  @doc """
  Checks if the given device state has the KNX fault bit set.
  """
  defguard is_knx_fault(value)
           when check_bit(value, 1)

  @doc """
  Checks if the given device state has the IP fault bit set.
  """
  defguard is_ip_fault(value)
           when check_bit(value, 2)
end
