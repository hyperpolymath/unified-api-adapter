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

public export
data Lease : Type -> Phase -> Type where
  IdleLease : Registry endpoint -> Lease endpoint Idle
  CallingLease : Registry endpoint -> Lease endpoint Calling
  ReleasedLease : Lease endpoint Released

public export
borrow : (1 owner : Lease endpoint Idle) -> Lease endpoint Calling
borrow (IdleLease entries) = CallingLease entries

public export
returnBorrow : (1 call : Lease endpoint Calling) -> Lease endpoint Idle
returnBorrow (CallingLease entries) = IdleLease entries

public export
release : (1 owner : Lease endpoint Idle) -> Lease endpoint Released
release (IdleLease _) = ReleasedLease

public export
borrowReturnsOwner : (r : Registry endpoint) ->
  returnBorrow (borrow (IdleLease r)) = IdleLease r
borrowReturnsOwner r = Refl

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
