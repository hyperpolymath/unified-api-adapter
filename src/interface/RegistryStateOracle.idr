-- SPDX-License-Identifier: MPL-2.0
module Main
import Abi.Registry
import Abi.RegistryState
import Abi.RegistryOwnership
import Abi.Status
%default total

record Observation where
  constructor Observe
  code : Bits8
  state : State Nat
  chosen : Maybe Nat

fromReply : Reply Nat -> Observation
fromReply r = Observe (statusTag (status r)) (next r) Nothing

step : Nat -> Slot -> State Nat -> Observation
step 0 k s = fromReply (register k 11 s)
step 1 k s = fromReply (register k 22 s)
step 2 k s = fromReply (unregister k s)
step 3 k s = case beginCall k s of
  Left r => fromReply r
  Right call => Observe 0 (duringCall call) (Just (selected call))
step _ k s = Observe 0 (normalReturn (MkInvocation (entries s) 0)) Nothing

endpoint : Nat -> Maybe Nat
endpoint 0 = Nothing
endpoint 1 = Just 11
endpoint _ = Just 22

number : Maybe Nat -> String
number Nothing = "0"
number (Just n) = show n

render : Observation -> String
render (Observe code s chosen) =
  show code ++ " " ++ number (restEndpoint (entries s)) ++ " " ++
  number (mcpEndpoint (entries s)) ++ " " ++
  (if busy s then "1" else "0") ++ " " ++ number chosen

main : IO ()
main = do
  for_ [0,1,2] $ \r =>
    for_ [0,1,2] $ \m =>
      for_ [False,True] $ \b =>
        for_ [RESTSlot,MCPSlot] $ \k =>
          for_ [0,1,2,3,4] $ \a =>
            for_ [0,1,2,3,4] $ \z => do
              let first = step a k (MkState (MkRegistry (endpoint r) (endpoint m)) b)
              let second = step z k (state first)
              putStrLn (render first ++ " " ++ render second)
  for_ [-2147483648,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,256,2147483647] $ \z =>
    putStrLn ("status " ++ show z ++ " " ++ show (statusTag (sanitize z)))
