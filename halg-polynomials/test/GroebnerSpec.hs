{-# LANGUAGE DataKinds, ExplicitNamespaces, GADTs, PatternSynonyms #-}
{-# OPTIONS_GHC -fno-warn-unused-imports #-}
module GroebnerSpec where
import Algebra.Algorithms.Groebner
import Algebra.Internal            (pattern (:<), KnownNat, pattern NilL, SNat)
import Algebra.Ring.Ideal
import Algebra.Ring.Polynomial
import Utils

import           Control.Monad
import qualified Data.Foldable          as F
import           Data.List              (delete)
import qualified Data.Sized.Builtin     as SV
import           Numeric.Field.Fraction (Fraction)
import           Test.Hspec
import           Test.Hspec.QuickCheck
import           Test.QuickCheck
import           Utils

asGenListOf :: Gen [a] -> a -> Gen [a]
asGenListOf = const

spec :: Spec
spec = parallel $ do
  describe "divModPolynomial" $ modifyMaxSize (const 25) $ modifyMaxSuccess (const 100) $ do
    prop "remainder cannot be diveided by any denoms (ternary)" $
      checkForArity [1..4] prop_indivisible
    prop "satisfies a_i f_i /= 0 ==> deg(f) >= deg (a_i f_i)" $
      checkForArity [1..4] prop_degdecay
    prop "divides correctly" $
      checkForArity [1..4] prop_divCorrect
  describe "calcGroebnerBasis" $ modifyMaxSize (const 4) $ modifyMaxSuccess (const 25) $ do
    prop "passes S-test" $
      checkForArity [2..3] prop_passesSTest
    prop "divides all original generators" $ do
      checkForArity [2..3] prop_groebnerDivsOrig
    it "generates the same ideal as original" $ do
      pendingWith "need example"
    it "produces minimal basis" $ do
      checkForArity [2..3] prop_isMinimal
    it "produces reduced basis" $ do
      checkForArity [2..3] prop_isReduced
  describe "isIdealMember" $ do
    it "determins membership correctly" $ do
      pendingWith "need example"
  describe "intersection" $ modifyMaxSize (const 3) $ modifyMaxSuccess (const 50) $ do
    it "can calculate correctly" $ do
      checkForArity [2..3] prop_intersection
    it "can solve test-cases correctly" $ do
      forM_ ics_binary $ \(IC i j ans) ->
        F.toList (intersection [toIdeal i, toIdeal j]) `shouldBe` ans

prop_intersection :: KnownNat n => SNat n -> Property
prop_intersection sdim =
  forAll (idealOfArity sdim) $ \ideal ->
  forAll (idealOfArity sdim) $ \jdeal ->
  forAll (polynomialOfArity sdim) $ \f ->
  (f `isIdealMember` ideal && f `isIdealMember` jdeal)
  == f `isIdealMember` intersection [ideal, jdeal]

prop_isMinimal :: KnownNat n => SNat n -> Property
prop_isMinimal sdim =
  forAll (idealOfArity sdim) $ \ideal ->
  let gs = calcGroebnerBasis ideal
  in all ((== 1) . leadingCoeff) gs &&
     all (\f -> all (\g -> not $ leadingMonomial g `divs` leadingMonomial f) (delete f gs)) gs

prop_isReduced :: KnownNat n => SNat n -> Property
prop_isReduced sdim =
  forAll (idealOfArity sdim) $ \ideal ->
  let gs = calcGroebnerBasis ideal
  in all ((== 1) . leadingCoeff) gs &&
     all (\f -> all (\g -> all (\(_, m) -> not $ leadingMonomial g `divs` m) $ getTerms f) (delete f gs)) gs

prop_passesSTest :: KnownNat n => SNat n -> Property
prop_passesSTest sdim =
  forAll (sized $ \size -> vectorOf size (polynomialOfArity sdim)) $ \ideal ->
  let gs = calcGroebnerBasis $ toIdeal ideal
  in all ((== 0) . (`modPolynomial` gs)) [sPolynomial f g | f <- gs, g <- gs, f /= g]

prop_groebnerDivsOrig :: KnownNat n => SNat n -> Property
prop_groebnerDivsOrig sdim =
  forAll (elements [3..15]) $ \count ->
  forAll (vectorOf count (polynomialOfArity sdim)) $ \ideal ->
  let gs = calcGroebnerBasis $ toIdeal ideal
  in all ((== 0) . (`modPolynomial` gs)) ideal

prop_divCorrect :: KnownNat n => SNat n -> Property
prop_divCorrect sdim =
  forAll (polynomialOfArity sdim) $ \poly ->
  forAll (idealOfArity sdim) $ \ideal ->
  let dvs = generators ideal
      (qds, r) = poly `divModPolynomial` dvs
  in poly == sum (map (uncurry (*)) qds) + r

prop_indivisible :: KnownNat n => SNat n -> Property
prop_indivisible sdim =
  forAll (polynomialOfArity sdim) $ \poly ->
  forAll (idealOfArity sdim) $ \ideal ->
  let dvs = generators ideal
      (_, r) = changeOrder Grevlex poly `divModPolynomial` dvs
  in r /= 0 ==> all (\f -> all (\(_, m) -> not $ leadingMonomial f `divs` m) $ getTerms r)  dvs

prop_degdecay :: KnownNat n => SNat n -> Property
prop_degdecay sdim =
  forAll (polynomialOfArity sdim) $ \poly ->
  forAll (idealOfArity sdim) $ \ideal ->
  let dvs = generators ideal
      (qs, _) = poly `divModPolynomial` dvs
  in all (\(a, f) -> (a * f == 0) || (leadingMonomial poly >= leadingMonomial (a * f))) qs

data IntersectCase r ord n = IC [OrderedPolynomial r ord n] [OrderedPolynomial r ord n] [OrderedPolynomial r ord n]

ics_binary :: [IntersectCase (Fraction Integer) Grevlex 2]
ics_binary =
  let [x, y] = F.toList allVars
  in [IC [x*y] [y] [x*y]]
