defmodule KNXex.FrameDecoder do
  @moduledoc """
  This module contains all the binary matching logic for the KNX frames (inlined through macros from the actual frame modules).

  Frames that are inlined into this module (using `use`), have to implement the `decode_frame/3` function with binary matching in the header.
  """

  alias KNXex.Constants
  alias KNXex.Frames

  require Constants

  @doc """
  Decodes a KNX frame from a binary string.

  `:ignore` will be returned as a default fallback, if no frame decoder matches.
  """
  @spec decode_frame(protocol_version :: integer(), request_type :: atom(), data :: bitstring()) ::
          {:ok, struct()} | {:error, term()} | :ignore

  # Inline Frame Decoders
  # Use the binary matching performance
  use Frames.DescriptionRequestFrame
  use Frames.DescriptionResponseFrame
  use Frames.RoutingBusyFrame
  use Frames.RoutingIndicationFrame
  use Frames.RoutingLostMessageFrame
  use Frames.SearchRequestFrame
  use Frames.SearchResponseFrame

  def decode_frame(_version, _request, _binary) do
    # Trick dialyzer to not complain about pattern match errors
    case :erlang.phash2(1, 1) do
      0 -> :ignore
      1 -> {:error, :phash_failed_us}
    end
  end
end
