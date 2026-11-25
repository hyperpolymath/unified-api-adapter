-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
module Abi.RegistryLifetime
import Abi.Registry
import Abi.RegistryState
import Abi.Status

%default total

||| Caller-side permission ledger. The indices count retained registrations and
||| transient readers of a supplied resource; they are not stored by the Zig ABI.
||| Acquisition cannot establish that a copyable pointer is exclusive or live.
export
data Permit : Type -> Nat -> Nat -> Type where
  Own : (1 payload : resource) -> Permit resource retained readers

export
acquire : (1 payload : resource) -> Permit resource 0 0
acquire payload = Own payload

export
retain : (1 permit : Permit resource retained readers) ->
  Permit resource (S retained) readers
retain (Own payload) = Own payload

export
dropRetention : (1 permit : Permit resource (S retained) readers) ->
  Permit resource retained readers
dropRetention (Own payload) = Own payload

export
borrowRead : (1 permit : Permit resource retained readers) ->
  Permit resource retained (S readers)
borrowRead (Own payload) = Own payload

export
returnRead : (1 permit : Permit resource retained (S readers)) ->
  Permit resource retained readers
returnRead (Own payload) = Own payload

export
release : ((1 payload : resource) -> ()) ->
  (1 permit : Permit resource 0 0) -> ()
release destroy (Own payload) = destroy payload

export
retainDropRestores : (permit : Permit resource retained readers) ->
  dropRetention (retain permit) = permit
retainDropRestores (Own payload) = Refl

export
borrowReturnRestores : (permit : Permit resource retained readers) ->
  returnRead (borrowRead permit) = permit
borrowReturnRestores (Own payload) = Refl

||| Native destroy frees the registry allocation only, on an idle live pointer.
||| Destroyed means its registrations are detached, not that their resources
||| were freed. Valid-pointer, allocator and caller-serialization premises remain.
public export
data DestroyResult : Type -> Type where
  Refused : Status -> Maybe (State endpoint) -> DestroyResult endpoint
  Destroyed : DestroyResult endpoint

public export
destroyRegistry : Maybe (State endpoint) -> DestroyResult endpoint
destroyRegistry Nothing = Refused NullPointer Nothing
destroyRegistry (Just (MkState entries True)) =
  Refused ProcessFailed (Just (MkState entries True))
destroyRegistry (Just (MkState entries False)) = Destroyed

public export
retainedAfter : DestroyResult endpoint -> Registry endpoint
retainedAfter (Refused _ Nothing) = emptyRegistry
retainedAfter (Refused _ (Just state)) = entries state
retainedAfter Destroyed = emptyRegistry

public export
busyDestroyRefuses : (r : Registry endpoint) ->
  destroyRegistry (Just (MkState r True)) =
    Refused ProcessFailed (Just (MkState r True))
busyDestroyRefuses r = Refl

public export
idleDestroyDetaches : (r : Registry endpoint) ->
  retainedAfter (destroyRegistry (Just (MkState r False))) = emptyRegistry
idleDestroyDetaches r = Refl

-- A shared callback/context registered in two slots needs two retentions.
-- Unregister drops one; idle destroy drops every remaining registration.
-- Transient input borrowing adds readers independently. The caller must apply
-- these transitions consistently with native successes; raw callers can violate
-- the ledger, so it is not a dynamic stale-pointer or lifetime validator.
