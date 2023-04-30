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
    function getSingleSidedMintLiquidityOutAmountA(
        uint256 totalLiquidity,
        uint256 mintAmountA,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public pure returns (uint256 liquidityOut, uint256 tokenAToSwap, uint256 equivalentTokenB) {
        // movingAveragePriceA is a UQ112x112 and so is a uint224 that needs to be divided by 2^112 after being multiplied.
        // Here we risk `movingAveragePriceA * (totalA + mintAmountA)` overflowing since we multiple a uint224 by the sum
        //   of two uint112s, however TODO
        // Conversely, if this does overflow, then it means the price is highly volatile which would be grounds for having triggered
        //   the timelock in the first place to prevent single-sided operations being undertaken.
        // As such we can get away with not using a muldiv that supports phantom overflow.
        tokenAToSwap = (mintAmountA * totalB) / (((movingAveragePriceA * (totalA + mintAmountA)) / 2 ** 112) + totalB);
        // Here we don't risk undesired overflow because if `tokenAToSwap * movingAveragePriceA` exceeded 2^256 then it
        //   would necessarily mean `equivalentTokenB` exceeded 2^112, which would result in breaking the poolX unit112 limits.
        equivalentTokenB = (tokenAToSwap * movingAveragePriceA) / 2 ** 112;
        // Update totals to account for the fixed price swap
        totalA += tokenAToSwap;
        totalB -= equivalentTokenB;
        uint256 tokenARemaining = mintAmountA - tokenAToSwap;
        liquidityOut =
            getDualSidedMintLiquidityOutAmount(totalLiquidity, tokenARemaining, equivalentTokenB, totalA, totalB);
    }

    /// @dev Refer to `/notes/mint-math.md`
    function getSingleSidedMintLiquidityOutAmountB(
        uint256 totalLiquidity,
        uint256 mintAmountB,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public pure returns (uint256 liquidityOut, uint256 tokenBToSwap, uint256 equivalentTokenA) {
        // `movingAveragePriceA` is a UQ112x112 and so is a uint224 that needs to be divided by 2^112 after being multiplied.
        // Here we need to use the inverse price however, which means we multiply the numerator by 2^112 and then divide that
        //   by movingAveragePriceA to get the result, all without risk of overflow.
        tokenBToSwap = (mintAmountB * totalA) / (((2 ** 112 * (totalB + mintAmountB)) / movingAveragePriceA) + totalA);
        // Inverse price so again we can use it without overflow risk
        equivalentTokenA = (tokenBToSwap * (2 ** 112)) / movingAveragePriceA;
        // Update totals to account for the fixed price swap
        totalA -= equivalentTokenA;
        totalB += tokenBToSwap;
        uint256 tokenBRemaining = mintAmountB - tokenBToSwap;
        liquidityOut =
            getDualSidedMintLiquidityOutAmount(totalLiquidity, equivalentTokenA, tokenBRemaining, totalA, totalB);
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
    function getSingleSidedBurnOutputAmountsA(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public pure returns (uint256 amountOutA, uint256 amountOutB) {
        // Calculate what the liquidity is worth in terms of both tokens
        (amountOutA, amountOutB) = getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        // Here we need to use the inverse price however, which means we multiply the numerator by 2^112 and then divide that
        //   by movingAveragePriceA to get the result, all without risk of overflow.
        uint256 equivalentTokenA = (amountOutB * (2 ** 112)) / movingAveragePriceA;
        amountOutA = amountOutA + equivalentTokenA;
        amountOutB = 0;
    }

    /// @dev Refer to `/notes/burn-math.md`
    function getSingleSidedBurnOutputAmountsB(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public pure returns (uint256 amountOutA, uint256 amountOutB) {
        // Calculate what the liquidity is worth in terms of both tokens
        (amountOutA, amountOutB) = getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        // Whilst we appear to risk overflow here, the final `equivalentTokenB` needs to be smaller than the reservoir
        //   which soft-caps it at 2^112.
        // As such, any combination of amountOutA and movingAveragePriceA that would overflow would violate the next
        //   check anyway, and we can therefore safely ignore the overflow potential.
        uint256 equivalentTokenB = (amountOutA * movingAveragePriceA) / 2 ** 112;
        amountOutA = 0;
        amountOutB = amountOutB + equivalentTokenB;
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
