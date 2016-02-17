-- In order to write a test, we have to import the module Test.EasyCheck:
import Test.EasyCheck

-- We import the System module for performing some I/O tests on operations
-- in this module:
import System

--------------------------------------------------------------------------
-- Deterministic tests:

-- We can write simple equational tests where both sides
-- evaluate to a single value:
rev_123 = reverse [1,2,3] -=- [3,2,1]

not_True  = not True  -=- False
not_False = not False -=- True

-- However, we can also use EasyCheck to guess input values to check
-- parameterized properties (currently, checking of parameterized properties
-- is only supported by KiCS2, therefore, such tests are ignored in PAKCS):
not_not_is_id b = not (not b) -=- b

-- In the former test, EasyCheck makes an exhaustive test by enumerating
-- all possible Boolean values. For types, with infinitely many values,
-- this is not possible. Anyway, EasyCheck can also enumerate many values,
-- e.g., to check the commutativity property of the addition on integers:
plusComm :: Int -> Int -> Prop
plusComm x y = x + y -=- y + x

-- We can even write a polymorphic test:
rev_rev_is_id :: [a] -> Prop
rev_rev_is_id xs = reverse (reverse xs) -=- xs
-- A polymorphic test will be automatically transformed into the same
-- test specialized to Booleans.

-- Nevertheless, we can still define our own specialization:
rev_rev_is_id_int :: [Int] -> Prop
rev_rev_is_id_int = rev_rev_is_id

-- Sometimes it is necessary to add a condition to the generated
-- test inputs. This can be done by the operator `==>`:
tail_length xs =
 not (null xs)  ==>  length (tail xs) -=- length xs - 1

--------------------------------------------------------------------------
-- Of course, in Curry we also have to test Non-deterministic operations
-- like `coin`:
coin = 0 ? 1

-- We can test whether `coin` evaluates at least to some value:
coin_yields_0 = coin ~> 0

coin_yields_1 = coin ~> 1

-- If we want to check for all results of an operation, we can also
-- check the set of all results for equality:
coin_yields_0_1 = coin <~> (0?1)

-- In this way, we can check whether Curry really implements call-time choice:
double x = x+x

double_coin_yields_0_2 = double coin <~> (0?2)

-- Note that the operator `<~>` compares the set of all results of both sides.
-- Thus, duplicated elements do not count:
coin_plus_coin = coin+coin <~> (0?1?2)

-- However, if we are interested in the detailed operational semantics,
-- we could also compare the multi-sets of the values with the operator `<~~>`:
coin_plus_coin_multi = coin+coin <~~> (0?1?1?2)


-- As a more advanced example, we want to test whether the operation
-- `last` defined with a functional pattern always yields a single result.
-- This can be done by checking whether to different calls to `last`
-- on the same input yield always identical values:
last :: [a] -> a
last (_ ++ [x]) = x

last_is_deterministic xs =
 let ys = last xs
  in ys==ys ==> (ys == last xs) <~> True

--------------------------------------------------------------------------
-- I/O tests:

-- We can also check properties of I/O actions. In this case,
-- these I/O actions must be deterministic (otherwise, currycheck reports
-- failure) and we can specify which value we expect from the I/O action.

-- As an example, we check the setting of environment variables.
-- For this purpose, we use the following environment variable:
evar = "abc123"

-- First, we check whether setting this variable works:
set_environ = (setEnviron evar "SET" >> getEnviron evar) `yields` "SET"

-- Now we check whether unsetting workds:
unset_environ = (unsetEnviron evar >> getEnviron evar) `yields` ""

-- We can also compare the results of two actions with `sameAs`:
sameIO = return (6*7) `sameAs` return 42

--------------------------------------------------------------------------