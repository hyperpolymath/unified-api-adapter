-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
module RegistryCheck
import Abi.Protocol
import Abi.ProtocolFinite
import Abi.Registry
import Abi.Status
import System
import Data.List
import Data.String

%default total

observe : Either Status Bits8 -> (Bits8, Bits8)
observe (Left s) = (statusTag s, 0)
observe (Right endpoint) = (0, endpoint)

expected : Bool -> Bool -> Nat -> (Bits8, Bits8)
expected rest mcp n =
  if n == 0 || n > 9 then (2, 0)
  else if n == 1 && mcp then (0, 1)
  else if n == 9 && rest then (0, 9)
  else (11, 0)

check : Bool -> Bool -> Nat -> Bool
check rest mcp n =
  let r = MkRegistry (if rest then Just 9 else Nothing)
                     (if mcp then Just 1 else Nothing)
      tag : Bits8 = cast n
  in observe (dispatchTag r tag) == expected rest mcp n &&
     map protocolTag (protocolFromWire tag) == map protocolTag (protocolFromTag tag)

row : Bool -> Bool -> Nat -> String
row rest mcp n =
  let r = MkRegistry (if rest then Just 9 else Nothing)
                     (if mcp then Just 1 else Nothing)
      (status, endpoint) = observe (dispatchTag r (cast n))
      mask : Nat = (if rest then 1 else 0) + (if mcp then 2 else 0)
  in "case," ++ show mask ++ "," ++ show n ++ "," ++ show status ++ "," ++ show endpoint

main : IO ()
main = if all (\rest => all (\mcp => all (check rest mcp) [0..255]) [False, True]) [False, True]
       then do
         putStr (unlines (concatMap (\rest => concatMap (\mcp => map (row rest mcp) [0..255]) [False, True]) [False, True]))
         putStrLn "PASS: all 256 tags x four registration states; original decoder agrees"
       else die "FAIL: registry, status or primitive decoder disagreement"
