-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
module Abi.RegistryOwnership
import Abi.Registry
import Abi.RegistryState

%default total

||| Logical ownership protocol. It does not manufacture pointer validity or
||| establish that arbitrary foreign callers obey linearity.
public export
data Phase = Idle | Calling | Released

export
data Lease : Type -> Phase -> Type where
  IdleLease : (1 payload : resource) -> Lease resource Idle
  CallingLease : (1 payload : resource) -> Lease resource Calling
  ReleasedLease : Lease resource Released

||| Acquisition consumes a supplied resource; it cannot establish that a
||| copyable value was an exclusive native allocation in the first place.
export
acquire : (1 payload : resource) -> Lease resource Idle
acquire payload = IdleLease payload

export
borrow : (1 owner : Lease resource Idle) -> Lease resource Calling
borrow (IdleLease entries) = CallingLease entries

export
returnBorrow : (1 call : Lease resource Calling) -> Lease resource Idle
returnBorrow (CallingLease entries) = IdleLease entries

export
release : ((1 payload : resource) -> ()) ->
  (1 owner : Lease resource Idle) -> Lease resource Released
release destroy (IdleLease payload) = case destroy payload of
  () => ReleasedLease

export
borrowReturnsOwner : (owner : Lease resource Idle) ->
  returnBorrow (borrow owner) = owner
borrowReturnsOwner (IdleLease payload) = Refl

||| A normal callback may change its own disjoint context, but must preserve
||| both registry endpoints. This equality is a premise, not a runtime check.
public export
record CallbackFrame (before : Registry endpoint) where
  constructor FramedReturn
  after : Registry endpoint
  preserved : after = before

public export
finishCurrent : State endpoint -> State endpoint
finishCurrent s = MkState (entries s) False

public export
callbackReturnRestores : (before : Registry endpoint) ->
  (result : CallbackFrame before) ->
  finishCurrent (MkState (after result) True) = MkState before False
callbackReturnRestores before (FramedReturn before Refl) = Refl

-- No transition releases a Calling lease: destroy is permitted only at Idle.
-- Raw aliases, concurrent calls and non-local exits remain external obligations.
