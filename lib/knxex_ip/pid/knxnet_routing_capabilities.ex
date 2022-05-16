defmodule KNXexIP.PID.KNXnetRoutingCapabilities do
  @moduledoc """
  KNXnet/IP Parameter Object "KNXnet/IP Routing Capabilities".
  """

  import KNXexIP.Macro

  defconstant(:meta, :pid, 70)
  defconstant(:meta, :name, "KNXnet/IP Routing Capabilities")

  defconstant(:bits, :stats_queue_overflow, 0)
  defconstant(:bits, :stats_transmitted_telegrams, 1)
  defconstant(:bits, :priority_fifo, 2)
  defconstant(:bits, :multiple_knx_installations, 3)
  defconstant(:bits, :group_address_mapping, 4)

  # Checks if the value is a struct or an int, and checks if the bit is set (bit as integer value, i.e. bit 0 = 1).
  @spec check_bit(integer(), integer()) :: Macro.t()
  defguardp check_bit(t, value)
            when is_integer(t) and :erlang.band(t, value) > 0

  @doc """
  Checks if the given routing capabilities has the statistics queue overflow capability bit set.
  """
  defguard has_stats_queue_overflow(value)
           when check_bit(value, 1)

  @doc """
  Checks if the given routing capabilities has the statistics transmitted telegrams capability bit set.
  """
  defguard has_stats_transmitted_telegrams(value)
           when check_bit(value, 2)

  @doc """
  Checks if the given routing capabilities has the priority/FIFO capability bit set.
  """
  defguard has_priority_fifo(value)
           when check_bit(value, 4)

  @doc """
  Checks if the given routing capabilities has the multiple KNX installations capability bit set.
  """
  defguard has_multiple_knx_installations(value)
           when check_bit(value, 8)

  @doc """
  Checks if the given routing capabilities has the group address mapping capability bit set.
  """
  defguard has_group_address_mapping(value)
           when check_bit(value, 16)
end
