-- Various test functions

f :: [a] -> [a] -> a
f xs ys | xs == _++[x] && ys == _++[x]++_ = x   where x free

main :: Int
main = f [1,2] [2,1]
