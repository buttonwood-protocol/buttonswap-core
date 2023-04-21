// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Math} from "./Math.sol";

library PairMath {
    /// @dev Refer to `/notes/mint-math.md`
    function getDualSidedMintLiquidityOutAmount(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 totalA,
        uint256 totalB
    ) public pure returns (uint256 liquidityOut) {
        liquidityOut = Math.min((totalLiquidity * amountInA) / totalA, (totalLiquidity * amountInB) / totalB);
    }

    /// @dev Refer to `/notes/mint-math.md`
    function getSingleSidedMintLiquidityOutAmount(
        uint256 totalLiquidity,
        uint256 mintAmountB,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA
    ) public pure returns (uint256 liquidityOut) {
        liquidityOut = (totalLiquidity * mintAmountB * poolA) / (poolB * (poolA + poolA + reservoirA));
    }

    /// @dev Refer to `/notes/burn-math.md`
    function getDualSidedBurnOutputAmounts(uint256 totalLiquidity, uint256 liquidityIn, uint256 totalA, uint256 totalB)
        public
        pure
        returns (uint256 amountOutA, uint256 amountOutB)
    {
        amountOutA = (totalA * liquidityIn) / totalLiquidity;
        amountOutB = (totalB * liquidityIn) / totalLiquidity;
    }

    /// @dev Refer to `/notes/burn-math.md`
    function getSingleSidedBurnOutputAmounts(
        uint256 totalLiquidity,
        uint256 burnAmount,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA,
        uint256 reservoirB
    ) public pure returns (uint256 amountOutA, uint256 amountOutB) {
        if (reservoirA > 0) {
            amountOutA = (burnAmount * (reservoirA + poolA + poolA)) / totalLiquidity;
        } else {
            amountOutB = (burnAmount * (reservoirB + poolB + poolB)) / totalLiquidity;
        }
    }

    /// @dev Refer to `/notes/swap-math.md`
    function getSwapOutputAmount(uint256 inputAmount, uint256 poolInput, uint256 poolOutput)
        public
        pure
        returns (uint256 outputAmount)
    {
        outputAmount = (poolOutput * inputAmount * 997) / ((poolInput * 1000) + (inputAmount * 997));
    }

    /// @dev Refer to `/notes/fee-math.md`
    function getProtocolFeeLiquidityMinted(uint256 totalLiquidity, uint256 kLast, uint256 k)
        public
        pure
        returns (uint256 liquidityOut)
    {
        uint256 rootKLast = Math.sqrt(kLast);
        uint256 rootK = Math.sqrt(k);
        liquidityOut = (totalLiquidity * (rootK - rootKLast)) / ((5 * rootK) + rootKLast);
    }
}
