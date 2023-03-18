// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Math} from "src/libraries/Math.sol";

library PairMath {
    /// @dev Refer to `/notes/swap-math.md`
    function getOutputAmount(uint256 inputAmount, uint256 poolInput, uint256 poolOutput)
        public
        pure
        returns (uint256)
    {
        return (poolOutput * inputAmount * 997) / ((poolInput * 1000) + (inputAmount * 997));
    }

    /// @dev Refer to `/notes/mint-math.md`
    function getNewDualSidedLiquidityAmount(
        uint256 totalLiquidity,
        uint256 mintAmountA,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA,
        uint256 reservoirB
    ) public pure returns (uint256) {
        return (totalLiquidity * 2 * mintAmountA) / (poolA + poolA + reservoirA + ((reservoirB * poolA) / poolB));
    }

    /// @dev Refer to `/notes/mint-math.md`
    function getNewSingleSidedLiquidityAmount(
        uint256 totalLiquidity,
        uint256 mintAmountB,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA
    ) public pure returns (uint256) {
        return (totalLiquidity * mintAmountB * poolA) / (poolB * (poolA + poolA + reservoirA));
    }

    /// @dev Refer to `/notes/burn-math.md`
    function getDualSidedBurnOutputAmounts(
        uint256 totalLiquidity,
        uint256 burnAmount,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA,
        uint256 reservoirB
    ) public pure returns (uint256, uint256) {
        uint256 amountA = ((poolA * burnAmount) / totalLiquidity) + ((reservoirA * burnAmount) / totalLiquidity);
        uint256 amountB = ((poolB * burnAmount) / totalLiquidity) + ((reservoirB * burnAmount) / totalLiquidity);
        return (amountA, amountB);
    }

    /// @dev Refer to `/notes/burn-math.md`
    function getSingleSidedBurnOutputAmounts(
        uint256 totalLiquidity,
        uint256 burnAmount,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA,
        uint256 reservoirB
    ) public pure returns (uint256, uint256) {
        uint256 amountA;
        uint256 amountB;
        if (reservoirA > 0) {
            amountA = (burnAmount * (reservoirA + poolA + poolA)) / totalLiquidity;
        } else {
            amountB = (burnAmount * (reservoirB + poolB + poolB)) / totalLiquidity;
        }
        return (amountA, amountB);
    }

    /// @dev Refer to `/notes/fee-math.md`
    function getProtocolFeeLiquidityMinted(uint256 totalLiquidity, uint256 kLast, uint256 k)
        public
        pure
        returns (uint256)
    {
        uint256 rootKLast = Math.sqrt(kLast);
        uint256 rootK = Math.sqrt(k);
        return (totalLiquidity * (rootK - rootKLast)) / ((5 * rootK) + rootKLast);
    }
}
