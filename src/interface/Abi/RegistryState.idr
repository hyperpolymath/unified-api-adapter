-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| State contract for one live, exclusively owned Zig registry.
||| Endpoint values include callback/context identity; no callback is executed
||| by this model. Raw-pointer validity and caller serialization are premises.
module Abi.RegistryState
import Abi.Registry
import Abi.Status

%default total

public export
data Slot = RESTSlot | MCPSlot

public export
record State endpoint where
  constructor MkState
  entries : Registry endpoint
  busy : Bool

public export
lookup : Slot -> Registry endpoint -> Maybe endpoint
lookup RESTSlot r = restEndpoint r
lookup MCPSlot r = mcpEndpoint r

public export
replace : Slot -> Maybe endpoint -> Registry endpoint -> Registry endpoint
replace RESTSlot e r = MkRegistry e (mcpEndpoint r)
replace MCPSlot e r = MkRegistry (restEndpoint r) e

public export
other : Slot -> Slot
other RESTSlot = MCPSlot
other MCPSlot = RESTSlot

||| Updating a slot neither changes nor fabricates the other endpoint.
public export
replaceFramesOther : (slot : Slot) -> (e : Maybe endpoint) ->
  (r : Registry endpoint) -> lookup (other slot) (replace slot e r) = lookup (other slot) r
replaceFramesOther RESTSlot e r = Refl
replaceFramesOther MCPSlot e r = Refl

public export
replaceSelectsExact : (slot : Slot) -> (e : Maybe endpoint) ->
  (r : Registry endpoint) -> lookup slot (replace slot e r) = e
replaceSelectsExact RESTSlot e r = Refl
replaceSelectsExact MCPSlot e r = Refl

public export
record Reply endpoint where
  constructor MkReply
  status : Status
  next : State endpoint

public export
register : Slot -> endpoint -> State endpoint -> Reply endpoint
register slot e (MkState r True) = MkReply ProcessFailed (MkState r True)
register slot e (MkState r False) = case lookup slot r of
  Just _ => MkReply AlreadyExists (MkState r False)
  Nothing => MkReply Ok (MkState (replace slot (Just e) r) False)

public export
unregister : Slot -> State endpoint -> Reply endpoint
unregister slot (MkState r True) = MkReply ProcessFailed (MkState r True)
unregister slot (MkState r False) = case lookup slot r of
  Nothing => MkReply NotFound (MkState r False)
  Just _ => MkReply Ok (MkState (replace slot Nothing r) False)

public export
busyRegisterRefuses : (slot : Slot) -> (e : endpoint) -> (r : Registry endpoint) ->
  register slot e (MkState r True) = MkReply ProcessFailed (MkState r True)
busyRegisterRefuses slot e r = Refl

public export
busyUnregisterRefuses : (slot : Slot) -> (r : Registry endpoint) ->
  unregister slot (MkState r True) = MkReply ProcessFailed (MkState r True)
busyUnregisterRefuses slot r = Refl

public export
duplicateRegisterFrames : (slot : Slot) -> (e old : endpoint) -> (r : Registry endpoint) ->
  lookup slot r = Just old ->
  register slot e (MkState r False) = MkReply AlreadyExists (MkState r False)
duplicateRegisterFrames slot e old r found = rewrite found in Refl

public export
absentUnregisterFrames : (slot : Slot) -> (r : Registry endpoint) ->
  lookup slot r = Nothing ->
  unregister slot (MkState r False) = MkReply NotFound (MkState r False)
absentUnregisterFrames slot r absent = rewrite absent in Refl

||| This is a logical call ticket, not an unforgeable machine pointer or a
||| proof of linear ownership. The snapshot is held across a NORMAL return.
public export
record Invocation endpoint where
  constructor MkInvocation
  snapshot : Registry endpoint
  selected : endpoint

public export
beginCall : Slot -> State endpoint -> Either (Reply endpoint) (Invocation endpoint)
beginCall slot (MkState r True) = Left (MkReply ProcessFailed (MkState r True))
beginCall slot (MkState r False) = case lookup slot r of
  Nothing => Left (MkReply Unsupported (MkState r False))
  Just e => Right (MkInvocation r e)

public export
duringCall : Invocation endpoint -> State endpoint
duringCall call = MkState (snapshot call) True

public export
normalReturn : Invocation endpoint -> State endpoint
normalReturn call = MkState (snapshot call) False

public export
beginPreservesIdentity : (slot : Slot) -> (r : Registry endpoint) -> (e : endpoint) ->
  lookup slot r = Just e ->
  beginCall slot (MkState r False) = Right (MkInvocation r e)
beginPreservesIdentity slot r e found = rewrite found in Refl

public export
normalReturnRestoresFrame : (call : Invocation endpoint) ->
  entries (normalReturn call) = entries (duringCall call)
normalReturnRestoresFrame call = Refl

public export
reentrantCallRefuses : (slot : Slot) -> (call : Invocation endpoint) ->
  beginCall slot (duringCall call) = Left (MkReply ProcessFailed (duringCall call))
reentrantCallRefuses slot call = Refl

||| Decode foreign signed status BEFORE narrowing it; values outside the
||| declared ABI range become ProcessFailed, never a fabricated status.
public export
sanitize : Integer -> Status
sanitize 0 = Ok
sanitize 1 = Err
sanitize 2 = InvalidParam
sanitize 3 = OutOfMemory
sanitize 4 = NullPointer
sanitize 5 = PathDenied
sanitize 6 = ProcessFailed
sanitize 7 = Timeout
sanitize 8 = NotFound
sanitize 9 = AlreadyExists
sanitize 10 = SlotExhausted
sanitize 11 = Unsupported
sanitize _ = ProcessFailed
