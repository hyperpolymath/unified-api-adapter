-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
module Main
import Abi.Protocol
import Abi.ProtocolFinite
import Data.Fin
%default total

present : Bits8 -> Nat
present tag = case protocolFromWire tag of
  Nothing => 0
  Just _ => 1

rows : Nat -> Nat -> IO ()
rows Z index = pure ()
rows (S fuel) index = do
  putStrLn (show index ++ " " ++ show (present (cast index)))
  rows fuel (S index)

main : IO ()
main = rows 256 0
