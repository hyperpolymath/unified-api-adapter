-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Registration is distinct from planned routes and successful invocation.
module Abi.Registry
import Abi.Protocol
import Abi.ProtocolFinite
import Abi.Status

%default total

||| An endpoint can be a handler value. Presence proves registration only,
||| not that a remote service is available or that invocation will succeed.
public export
record Registry endpoint where
  constructor MkRegistry
  restEndpoint : Maybe endpoint
  mcpEndpoint : Maybe endpoint

public export
emptyRegistry : Registry endpoint
emptyRegistry = MkRegistry Nothing Nothing

public export
lookupEndpoint : Registry endpoint -> ProtocolType -> Maybe endpoint
lookupEndpoint r REST = restEndpoint r
lookupEndpoint r MCP = mcpEndpoint r
lookupEndpoint _ _ = Nothing

public export
resolve : Maybe endpoint -> Either Status endpoint
resolve Nothing = Left Unsupported
resolve (Just e) = Right e

public export
dispatch : Registry endpoint -> ProtocolType -> Either Status endpoint
dispatch r p = resolve (lookupEndpoint r p)

public export
dispatchTag : Registry endpoint -> Bits8 -> Either Status endpoint
dispatchTag r tag = case protocolFromWire tag of
  Nothing => Left InvalidParam
  Just p => dispatch r p

resolveSound : (m : Maybe endpoint) -> (e : endpoint) ->
  resolve m = Right e -> m = Just e
resolveSound Nothing e Refl impossible
resolveSound (Just e) e Refl = Refl

||| Dispatch cannot fabricate a registered handler.
public export
successHasRegistration : (r : Registry endpoint) -> (p : ProtocolType) ->
  (e : endpoint) -> dispatch r p = Right e -> lookupEndpoint r p = Just e
successHasRegistration r p e prf = resolveSound (lookupEndpoint r p) e prf

emptyLookup : (p : ProtocolType) -> lookupEndpoint (the (Registry endpoint) Abi.Registry.emptyRegistry) p = Nothing
emptyLookup MCP = Refl
emptyLookup LSP = Refl
emptyLookup DAP = Refl
emptyLookup BSP = Refl
emptyLookup NeSy = Refl
emptyLookup Agentic = Refl
emptyLookup Fleet = Refl
emptyLookup GRPC = Refl
emptyLookup REST = Refl

public export
emptyRefuses : (p : ProtocolType) -> dispatch (the (Registry endpoint) Abi.Registry.emptyRegistry) p = Left Unsupported
emptyRefuses p = rewrite emptyLookup {endpoint} p in Refl

resolveNeverInvalid : (m : Maybe endpoint) -> Not (resolve m = Left InvalidParam)
resolveNeverInvalid Nothing Refl impossible
resolveNeverInvalid (Just _) Refl impossible

public export
knownNeverInvalid : (r : Registry endpoint) -> (p : ProtocolType) ->
  Not (dispatch r p = Left InvalidParam)
knownNeverInvalid r p = resolveNeverInvalid (lookupEndpoint r p)

public export
unknownTagRefused : (r : Registry endpoint) -> (tag : Bits8) ->
  protocolFromWire tag = Nothing -> dispatchTag r tag = Left InvalidParam
unknownTagRefused r tag prf = rewrite prf in Refl
