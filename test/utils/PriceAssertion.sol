// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UQ112x112} from "src/libraries/UQ112x112.sol";
import {Utils} from "test/utils/Utils.sol";

library PriceAssertion {
    using UQ112x112 for uint224;

    /// @notice Takes the terms for two ratios, `variableA`:`fixedB` and `targetA`:`targetB`.
    /// It computes the ratios for variableA's adjacent integers, and returns the variableA value that produces a ratio
    /// that is closest to the target ratio.
    function getLowestDeltaTermForRatio(uint112 variableA, uint112 fixedB, uint112 targetA, uint112 targetB)
        public
        pure
        returns (uint112)
    {
        uint224 deltaLower;
        uint224 deltaMiddle;
        uint224 deltaUpper;
        if (variableA == 1) {
            // Can't run the math with a value of 0
            // Represent it being skipped by setting to max int
            deltaLower = type(uint224).max;
        }
        if (variableA == type(uint112).max) {
            // Can't run the math with a value over max int
            // Represent it being skipped by setting to max int
            deltaUpper = type(uint224).max;
        }
        // Check which is higher so we get non-zero values when dividing
        if (variableA > fixedB) {
            uint224 target = UQ112x112.encode(targetA).uqdiv(targetB);
            if (deltaLower == 0) {
                deltaLower = Utils.getDelta224(UQ112x112.encode((variableA - 1)).uqdiv(fixedB), target);
            }
            deltaMiddle = Utils.getDelta224(UQ112x112.encode(variableA).uqdiv(fixedB), target);
            if (deltaUpper == 0) {
                deltaUpper = Utils.getDelta224(UQ112x112.encode((variableA + 1)).uqdiv(fixedB), target);
            }
        } else {
            uint224 target = UQ112x112.encode(targetB).uqdiv(targetA);
            if (deltaLower == 0) {
                deltaLower = Utils.getDelta224(UQ112x112.encode(fixedB).uqdiv((variableA - 1)), target);
            }
            deltaMiddle = Utils.getDelta224(UQ112x112.encode(fixedB).uqdiv(variableA), target);
            if (deltaUpper == 0) {
                deltaUpper = Utils.getDelta224(UQ112x112.encode(fixedB).uqdiv((variableA + 1)), target);
            }
        }
        // Check which has the lowest delta and return the corresponding variableA value
        if (deltaLower < deltaMiddle) {
            if (deltaLower < deltaUpper) {
                return variableA - 1;
            } else {
                return variableA + 1;
            }
        } else {
            if (deltaMiddle < deltaUpper) {
                return variableA;
            } else {
                return variableA + 1;
            }
        }
    }

    /// @notice Takes the terms for two ratios, `variableA`:`fixedB` and `targetA`:`targetB`.
    /// Checks whether the optimal value for variableA is within tolerance distance of variableA itself.
    /// The "optimal" value is one which produces the ratio closest to the target ratio.
    function isTermWithinTolerance(
        uint112 variableA,
        uint112 fixedB,
        uint112 targetA,
        uint112 targetB,
        uint112 tolerance
    ) public pure returns (bool) {
        uint112 currentVariableA = variableA;
        uint256 i;
        for (i = 0; i <= tolerance; i += 1) {
            // If input currentVariableA is the optimal value then the same value is returned
            // If the optimal value is far away instead, then currentVariableA will keep drifting towards it
            currentVariableA = getLowestDeltaTermForRatio(currentVariableA, fixedB, targetA, targetB);
        }
        // Check whether the final currentVariableA is sufficiently close to the initial variableA
        return Utils.getDelta112(currentVariableA, variableA) <= tolerance;
    }
}
