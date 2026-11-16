-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Finite protocol model. Primitive Bits8 conversion is a separate boundary.
module Abi.ProtocolFinite
import Abi.Protocol
import Data.Fin

%default total

public export
protocolFinTag : ProtocolType -> Fin 256
protocolFinTag MCP = 1
protocolFinTag LSP = 2
protocolFinTag DAP = 3
protocolFinTag BSP = 4
protocolFinTag NeSy = 5
protocolFinTag Agentic = 6
protocolFinTag Fleet = 7
protocolFinTag GRPC = 8
protocolFinTag REST = 9

public export
protocolFromFin : Fin 256 -> Maybe ProtocolType
protocolFromFin FZ = Nothing
protocolFromFin (FS FZ) = Just MCP
protocolFromFin (FS (FS FZ)) = Just LSP
protocolFromFin (FS (FS (FS FZ))) = Just DAP
protocolFromFin (FS (FS (FS (FS FZ)))) = Just BSP
protocolFromFin (FS (FS (FS (FS (FS FZ))))) = Just NeSy
protocolFromFin (FS (FS (FS (FS (FS (FS FZ)))))) = Just Agentic
protocolFromFin (FS (FS (FS (FS (FS (FS (FS FZ))))))) = Just Fleet
protocolFromFin (FS (FS (FS (FS (FS (FS (FS (FS FZ)))))))) = Just GRPC
protocolFromFin (FS (FS (FS (FS (FS (FS (FS (FS (FS FZ))))))))) = Just REST
protocolFromFin (FS (FS (FS (FS (FS (FS (FS (FS (FS (FS _)))))))))) = Nothing

public export
finiteRoundtrip : (p : ProtocolType) -> protocolFromFin (protocolFinTag p) = Just p
finiteRoundtrip MCP = Refl
finiteRoundtrip LSP = Refl
finiteRoundtrip DAP = Refl
finiteRoundtrip BSP = Refl
finiteRoundtrip NeSy = Refl
finiteRoundtrip Agentic = Refl
finiteRoundtrip Fleet = Refl
finiteRoundtrip GRPC = Refl
finiteRoundtrip REST = Refl

||| Reverse decoding law, including every inhabitant of Fin 256.
public export
finiteDecodeSound : (t : Fin 256) -> (p : ProtocolType) ->
  protocolFromFin t = Just p -> protocolFinTag p = t
finiteDecodeSound FZ p Refl impossible
finiteDecodeSound (FS FZ) MCP Refl = Refl
finiteDecodeSound (FS (FS FZ)) LSP Refl = Refl
finiteDecodeSound (FS (FS (FS FZ))) DAP Refl = Refl
finiteDecodeSound (FS (FS (FS (FS FZ)))) BSP Refl = Refl
finiteDecodeSound (FS (FS (FS (FS (FS FZ))))) NeSy Refl = Refl
finiteDecodeSound (FS (FS (FS (FS (FS (FS FZ)))))) Agentic Refl = Refl
finiteDecodeSound (FS (FS (FS (FS (FS (FS (FS FZ))))))) Fleet Refl = Refl
finiteDecodeSound (FS (FS (FS (FS (FS (FS (FS (FS FZ)))))))) GRPC Refl = Refl
finiteDecodeSound (FS (FS (FS (FS (FS (FS (FS (FS (FS FZ))))))))) REST Refl = Refl
finiteDecodeSound (FS (FS (FS (FS (FS (FS (FS (FS (FS (FS _)))))))))) p Refl impossible

||| No unchecked cast: an out-of-range conversion is refused.
||| This wrapper does not assert an unproved primitive Bits8 reflection law.
public export
protocolFromWire : Bits8 -> Maybe ProtocolType
protocolFromWire b = do
  finite <- natToFin (cast b) 256
  protocolFromFin finite
