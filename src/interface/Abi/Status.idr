-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Abi.Status: the result code every exported call returns.
|||
||| Tags 0..10 are developer-ecosystem/zig-api `ZigApi.ABI.Types.Result`,
||| unchanged, so an existing uapi_* caller reads the same codes. Tag 11,
||| Unsupported, is new: the adapter returns it for a protocol it names but has
||| no transport for (see Abi.Dispatch).
|||
||| Named Status, not Result, so it does not collide with the template's
||| Abi.Types.Result while that placeholder module remains.

module Abi.Status

%default total

public export
data Status
  = Ok             -- 0
  | Err            -- 1  unspecified failure
  | InvalidParam   -- 2  argument outside its domain (e.g. unknown protocol tag)
  | OutOfMemory    -- 3
  | NullPointer    -- 4
  | PathDenied     -- 5
  | ProcessFailed  -- 6  transport ran and failed
  | Timeout        -- 7
  | NotFound       -- 8
  | AlreadyExists  -- 9
  | SlotExhausted  -- 10
  | Unsupported    -- 11 protocol is named but has no transport

public export
statusTag : Status -> Bits8
statusTag Ok            = 0
statusTag Err           = 1
statusTag InvalidParam  = 2
statusTag OutOfMemory   = 3
statusTag NullPointer   = 4
statusTag PathDenied    = 5
statusTag ProcessFailed = 6
statusTag Timeout       = 7
statusTag NotFound      = 8
statusTag AlreadyExists = 9
statusTag SlotExhausted = 10
statusTag Unsupported   = 11

public export
statusFromTag : Bits8 -> Maybe Status
statusFromTag 0  = Just Ok
statusFromTag 1  = Just Err
statusFromTag 2  = Just InvalidParam
statusFromTag 3  = Just OutOfMemory
statusFromTag 4  = Just NullPointer
statusFromTag 5  = Just PathDenied
statusFromTag 6  = Just ProcessFailed
statusFromTag 7  = Just Timeout
statusFromTag 8  = Just NotFound
statusFromTag 9  = Just AlreadyExists
statusFromTag 10 = Just SlotExhausted
statusFromTag 11 = Just Unsupported
statusFromTag _  = Nothing

public export
statusRoundtrip : (s : Status) -> statusFromTag (statusTag s) = Just s
statusRoundtrip Ok            = Refl
statusRoundtrip Err           = Refl
statusRoundtrip InvalidParam  = Refl
statusRoundtrip OutOfMemory   = Refl
statusRoundtrip NullPointer   = Refl
statusRoundtrip PathDenied    = Refl
statusRoundtrip ProcessFailed = Refl
statusRoundtrip Timeout       = Refl
statusRoundtrip NotFound      = Refl
statusRoundtrip AlreadyExists = Refl
statusRoundtrip SlotExhausted = Refl
statusRoundtrip Unsupported   = Refl

||| Ok is tag 0, the C convention a caller tests with `== 0`.
public export
okIsZero : statusTag Ok = 0
okIsZero = Refl

||| Refusing an unimplemented protocol and rejecting a malformed tag are
||| different answers, and stay different on the wire.
public export
unsupportedNotInvalid : Not (statusTag Unsupported = statusTag InvalidParam)
unsupportedNotInvalid Refl impossible
