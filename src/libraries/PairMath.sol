// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Math} from "./Math.sol";

library PairMath {
    /// @dev Refer to `/notes/mint-math.md`
    function getDualSidedMintLiquidityOutAmount(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 activeA,
        uint256 activeB,
        uint256 inactiveA,
        uint256 inactiveB
    ) public pure returns (uint256 liquidityOut) {
        // We know at least one side has no inactive liquidity, and this simplifies the liquidity calculation
        if (inactiveA == 0) {
            liquidityOut = (totalLiquidity * 2 * amountInB) / (activeB + activeB + inactiveB);
        } else {
            liquidityOut = (totalLiquidity * 2 * amountInA) / (activeA + activeA + inactiveA);
        }
    }

    /// @dev Refer to `/notes/mint-math.md`
    function getSingleSidedMintLiquidityOutAmount(
        uint256 totalLiquidity,
        uint256 mintAmountB,
        uint256 activeA,
        uint256 activeB,
        uint256 inactiveA
    ) public pure returns (uint256 liquidityOut) {
        liquidityOut = (totalLiquidity * mintAmountB * activeA) / (activeB * (activeA + activeA + inactiveA));
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
        uint256 activeA,
        uint256 activeB,
        uint256 inactiveA,
        uint256 inactiveB
    ) public pure returns (uint256 amountOutA, uint256 amountOutB) {
        if (inactiveA > 0) {
            amountOutA = (burnAmount * (inactiveA + activeA + activeA)) / totalLiquidity;
        } else {
            amountOutB = (burnAmount * (inactiveB + activeB + activeB)) / totalLiquidity;
        }
    }

    /// @dev Refer to `/notes/swap-math.md`
    function getSwapOutputAmount(uint256 inputAmount, uint256 activeInput, uint256 activeOutput)
        public
        pure
        returns (uint256 outputAmount)
    {
        outputAmount = (activeOutput * inputAmount * 997) / ((activeInput * 1000) + (inputAmount * 997));
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
