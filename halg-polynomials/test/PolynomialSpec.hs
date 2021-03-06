{-# LANGUAGE DataKinds #-}
{-# OPTIONS_GHC -fno-warn-unused-imports #-}
module PolynomialSpec where
import Algebra.Algorithms.Groebner
import Algebra.Internal
import Algebra.Ring.Ideal
import Algebra.Ring.Polynomial
import Utils

import qualified Data.Matrix           as M
import qualified Data.Vector           as V
import           Test.Hspec
import           Test.Hspec.QuickCheck
import           Test.QuickCheck

asGenListOf :: Gen [a] -> a -> Gen [a]
asGenListOf = const

spec :: Spec
spec = parallel $ do
  return ()

prop_passesSTest :: SNat n -> Property
prop_passesSTest sdim = withKnownNat sdim $
  forAll (elements [3..15]) $ \count ->
  forAll (vectorOf count (polynomialOfArity sdim)) $ \ideal ->
  let gs = calcGroebnerBasis $ toIdeal ideal
  in all ((== 0) . (`modPolynomial` gs)) [sPolynomial f g | f <- gs, g <- gs, f /= g]

prop_groebnerDivsOrig :: SNat n -> Property
prop_groebnerDivsOrig sdim =
  withKnownNat sdim $
  forAll (elements [3..15]) $ \count ->
  forAll (vectorOf count (polynomialOfArity sdim)) $ \ideal ->
  let gs = calcGroebnerBasis $ toIdeal ideal
  in all ((== 0) . (`modPolynomial` gs)) ideal

prop_divCorrect :: SNat n -> Property
prop_divCorrect sdim =
  withKnownNat sdim $
  forAll (polynomialOfArity sdim) $ \poly ->
  forAll (idealOfArity sdim) $ \ideal ->
  let dvs = generators ideal
      (qds, r) = poly `divModPolynomial` dvs
  in poly == sum (map (uncurry (*)) qds) + r

prop_indivisible :: SNat n -> Property
prop_indivisible sdim =
  withKnownNat sdim $
  forAll (polynomialOfArity sdim) $ \poly ->
  forAll (idealOfArity sdim) $ \ideal ->
  let dvs = generators ideal
      (_, r) = changeOrder Grevlex poly `divModPolynomial` dvs
  in r /= 0 ==> all (\f -> all (\(_, m) -> not $ leadingMonomial f `divs` m) $ getTerms r)  dvs

prop_degdecay :: SNat n -> Property
prop_degdecay sdim =
  withKnownNat sdim $
  forAll (polynomialOfArity sdim) $ \poly ->
  forAll (idealOfArity sdim) $ \ideal ->
  let dvs = generators ideal
      (qs, _) = poly `divModPolynomial` dvs
  in all (\(a, f) -> (a * f == 0) || (leadingMonomial poly >= leadingMonomial (a * f))) qs

rank :: (Ord r, Fractional r) => M.Matrix r -> Int
rank mat =
  let Just (u, _, _, _,_, _) = M.luDecomp' mat
  in V.foldr (\a acc -> if a /= 0 then acc + 1 else acc) (0 :: Int) $ M.getDiag u
