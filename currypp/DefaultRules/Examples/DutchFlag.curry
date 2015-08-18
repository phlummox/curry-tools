{-# OPTIONS_CYMAKE -F --pgmF=currypp --optF=defaultrules #-}

-- Dijsktra's Dutch National Flag problem with functional patterns

data Color = Red | White | Blue

-- Formulation with sequential rule application:
solveD (x++[White]++y++[Red  ]++z) = solveD (x++[Red  ]++y++[White]++z)
solveD (x++[Blue ]++y++[Red  ]++z) = solveD (x++[Red  ]++y++[Blue ]++z)
solveD (x++[Blue ]++y++[White]++z) = solveD (x++[White]++y++[Blue ]++z)
solveD'default flag = flag

uni color = [] ? color : uni color

iflag = [White,Red,White,Blue,Red,Blue,White]

main = solveD iflag
 --> [Red,Red,White,White,White,Blue,Blue]
 -- but also many more (identical) solutions!

-------------------------------------------------------------------------------
-- Sergio's version to obtain a single solution:
dutch (r@(uni Red) ++ w@(uni White) ++ b@(uni Blue) ++ (Red:xs))
  | w++b /= []  = dutch (Red:r ++ w ++ b ++ xs)
dutch (r@(uni Red) ++ w@(uni White) ++ b@(uni Blue) ++ (White:xs))
  | b /= []     = dutch (r ++ White:w ++ b ++ xs)
dutch'default z = z