-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Abi.Dispatch: which transport serves a protocol, and what happens when none
||| does.
|||
||| The adapter's rule: every protocol the ABI names either routes to a working
||| transport or is refused with Unsupported. A tag that names no protocol is
||| InvalidParam. Nothing is silently accepted, and the two refusals are never
||| confused. The Zig runtime's transport table must agree with `route` on
||| every tag (checked by its seam tests).

module Abi.Dispatch

import Abi.Protocol
import Abi.Status
import Data.List

%default total

||| The transports the runtime implements.
public export
data Transport
  = ViaRest  -- HTTP/1.1 JSON (moved from developer-ecosystem/zig-api connector.zig)
  | ViaMcp   -- MCP JSON-RPC, over HTTP or stdio

||| Does a transport exist for this protocol?
public export
implemented : ProtocolType -> Bool
implemented REST = True
implemented MCP  = True
implemented _    = False

||| The dispatch decision for a decoded protocol.
public export
route : ProtocolType -> Either Status Transport
route REST    = Right ViaRest
route MCP     = Right ViaMcp
route LSP     = Left Unsupported
route DAP     = Left Unsupported
route BSP     = Left Unsupported
route NeSy    = Left Unsupported
route Agentic = Left Unsupported
route Fleet   = Left Unsupported
route GRPC    = Left Unsupported

||| The dispatch decision for a raw C tag.
public export
routeTag : Bits8 -> Either Status Transport
routeTag t = case protocolFromTag t of
  Nothing => Left InvalidParam
  Just p  => route p

-- ---------------------------------------------------------------------------
-- Proofs
-- ---------------------------------------------------------------------------

||| An implemented protocol routes to a transport.
public export
routeImplemented : (p : ProtocolType) -> implemented p = True
                -> (t : Transport ** route p = Right t)
routeImplemented REST    _   = (ViaRest ** Refl)
routeImplemented MCP     _   = (ViaMcp ** Refl)
routeImplemented LSP     prf = absurd prf
routeImplemented DAP     prf = absurd prf
routeImplemented BSP     prf = absurd prf
routeImplemented NeSy    prf = absurd prf
routeImplemented Agentic prf = absurd prf
routeImplemented Fleet   prf = absurd prf
routeImplemented GRPC    prf = absurd prf

||| An unimplemented protocol is refused with Unsupported, never routed.
public export
routeRefuses : (p : ProtocolType) -> implemented p = False
            -> route p = Left Unsupported
routeRefuses REST    prf = absurd prf
routeRefuses MCP     prf = absurd prf
routeRefuses LSP     _   = Refl
routeRefuses DAP     _   = Refl
routeRefuses BSP     _   = Refl
routeRefuses NeSy    _   = Refl
routeRefuses Agentic _   = Refl
routeRefuses Fleet   _   = Refl
routeRefuses GRPC    _   = Refl

||| `route` and `implemented` agree: a protocol routes exactly when it is
||| implemented. There is no third outcome.
public export
routeDecided : (p : ProtocolType)
            -> Either (implemented p = True, (t : Transport ** route p = Right t))
                      (implemented p = False, route p = Left Unsupported)
routeDecided p with (implemented p) proof eq
  _ | True  = Left (Refl, routeImplemented p eq)
  _ | False = Right (Refl, routeRefuses p eq)

||| A known protocol is never refused as InvalidParam: that answer is reserved
||| for tags that name no protocol.
public export
routeNeverInvalid : (p : ProtocolType) -> Not (route p = Left InvalidParam)
routeNeverInvalid REST    Refl impossible
routeNeverInvalid MCP     Refl impossible
routeNeverInvalid LSP     Refl impossible
routeNeverInvalid DAP     Refl impossible
routeNeverInvalid BSP     Refl impossible
routeNeverInvalid NeSy    Refl impossible
routeNeverInvalid Agentic Refl impossible
routeNeverInvalid Fleet   Refl impossible
routeNeverInvalid GRPC    Refl impossible

||| Dispatching a protocol's own tag is dispatching the protocol.
public export
routeTagSound : (p : ProtocolType) -> routeTag (protocolTag p) = route p
routeTagSound p = rewrite protocolRoundtrip p in Refl

||| A tag that names no protocol is InvalidParam.
public export
routeTagUnknown : (t : Bits8) -> protocolFromTag t = Nothing
               -> routeTag t = Left InvalidParam
routeTagUnknown t prf = rewrite prf in Refl

||| The reserved tag 0 is InvalidParam.
public export
routeTagZero : routeTag 0 = Left InvalidParam
routeTagZero = Refl

||| Census: exactly MCP and REST have transports today. Changing the set of
||| implemented protocols breaks this line, so the change is visible in review.
public export
implementedCensus : filter Abi.Dispatch.implemented Abi.Protocol.allProtocols = [MCP, REST]
implementedCensus = Refl
