-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Abi.Protocol: the closed set of wire protocols the adapter names.
|||
||| Extracted from boj-server `Boj.Protocol` (src/abi/Boj/Protocol.idr), where
||| the set is a column of the cartridge catalogue. Here it is the index of the
||| adapter's transport table (see Abi.Dispatch).
|||
||| The tags are boj-server's, unchanged: 1..9, with 0 reserved as invalid. A
||| caller that already speaks BOJ_PROTO_* speaks this ABI.

module Abi.Protocol

import Data.List.Elem

%default total

||| The wire protocols. CLOSED: adding a protocol is an ABI change.
public export
data ProtocolType
  = MCP       -- Model Context Protocol
  | LSP       -- Language Server Protocol
  | DAP       -- Debug Adapter Protocol
  | BSP       -- Build Server Protocol
  | NeSy      -- Neurosymbolic Protocol (proven-neurosym)
  | Agentic   -- Agentic Protocol (proven-agentic)
  | Fleet     -- Fleet Protocol (gitbot-fleet)
  | GRPC      -- gRPC
  | REST      -- REST over HTTP

||| C-ABI encoding. Mirrors boj-server `protocolToInt` and BOJ_PROTO_*.
public export
protocolTag : ProtocolType -> Bits8
protocolTag MCP     = 1
protocolTag LSP     = 2
protocolTag DAP     = 3
protocolTag BSP     = 4
protocolTag NeSy    = 5
protocolTag Agentic = 6
protocolTag Fleet   = 7
protocolTag GRPC    = 8
protocolTag REST    = 9

||| C-ABI decoding. Every tag outside 1..9 is Nothing: there is no default.
public export
protocolFromTag : Bits8 -> Maybe ProtocolType
protocolFromTag 1 = Just MCP
protocolFromTag 2 = Just LSP
protocolFromTag 3 = Just DAP
protocolFromTag 4 = Just BSP
protocolFromTag 5 = Just NeSy
protocolFromTag 6 = Just Agentic
protocolFromTag 7 = Just Fleet
protocolFromTag 8 = Just GRPC
protocolFromTag 9 = Just REST
protocolFromTag _ = Nothing

||| Decoding inverts encoding.
public export
protocolRoundtrip : (p : ProtocolType) -> protocolFromTag (protocolTag p) = Just p
protocolRoundtrip MCP     = Refl
protocolRoundtrip LSP     = Refl
protocolRoundtrip DAP     = Refl
protocolRoundtrip BSP     = Refl
protocolRoundtrip NeSy    = Refl
protocolRoundtrip Agentic = Refl
protocolRoundtrip Fleet   = Refl
protocolRoundtrip GRPC    = Refl
protocolRoundtrip REST    = Refl

justInjective : {0 x, y : t} -> Just x = Just y -> x = y
justInjective Refl = Refl

||| The encoding is injective: two protocols with one tag are one protocol.
public export
protocolTagInjective : (a, b : ProtocolType) -> protocolTag a = protocolTag b -> a = b
protocolTagInjective a b prf =
  justInjective $ trans (sym (protocolRoundtrip a))
                        (trans (cong protocolFromTag prf) (protocolRoundtrip b))

||| Tag 0 is reserved and decodes to nothing.
public export
tagZeroInvalid : protocolFromTag 0 = Nothing
tagZeroInvalid = Refl

||| Every protocol, in tag order.
public export
allProtocols : List ProtocolType
allProtocols = [MCP, LSP, DAP, BSP, NeSy, Agentic, Fleet, GRPC, REST]

||| allProtocols is complete: no protocol is missing from it.
public export
allProtocolsComplete : (p : ProtocolType) -> Elem p Abi.Protocol.allProtocols
allProtocolsComplete MCP     = Here
allProtocolsComplete LSP     = There Here
allProtocolsComplete DAP     = There (There Here)
allProtocolsComplete BSP     = There (There (There Here))
allProtocolsComplete NeSy    = There (There (There (There Here)))
allProtocolsComplete Agentic = There (There (There (There (There Here))))
allProtocolsComplete Fleet   = There (There (There (There (There (There Here)))))
allProtocolsComplete GRPC    = There (There (There (There (There (There (There Here))))))
allProtocolsComplete REST    = There (There (There (There (There (There (There (There Here)))))))

||| Human-readable label. Mirrors boj-server `protocolLabel`.
public export
protocolLabel : ProtocolType -> String
protocolLabel MCP     = "MCP"
protocolLabel LSP     = "LSP"
protocolLabel DAP     = "DAP"
protocolLabel BSP     = "BSP"
protocolLabel NeSy    = "NeSy"
protocolLabel Agentic = "Agentic"
protocolLabel Fleet   = "Fleet"
protocolLabel GRPC    = "gRPC"
protocolLabel REST    = "REST"
