// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {PairMath} from "../../src/libraries/PairMath.sol";
import {Math} from "../../src/libraries/Math.sol";

contract PairMathTest is Test {
    function test_getDualSidedMintLiquidityOutAmount_usingReservoirA(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA
    ) public {
        // Pools will be capped by uint112
        vm.assume(poolA < type(uint112).max);
        vm.assume(poolB < type(uint112).max);

        // Ensuring we use reservoirA
        vm.assume(reservoirA > 0);

        // Ensuring we don't overflow
        vm.assume(totalLiquidity < (type(uint256).max / 2));
        vm.assume(amountInA == 0 || totalLiquidity < (type(uint256).max / 2) / amountInA);
        vm.assume(reservoirA < (type(uint256).max - poolA) - poolA);

        uint256 liquidityOut = PairMath.getDualSidedMintLiquidityOutAmount(
            totalLiquidity, amountInA, amountInB, poolA, poolB, reservoirA, 0
        );
        uint256 expectedLiquidityOut = (totalLiquidity * 2 * amountInA) / (poolA + poolA + reservoirA);
        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }

    function test_getDualSidedMintLiquidityOutAmount_usingReservoirB(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirB
    ) public {
        // Pools will be capped by uint112
        vm.assume(poolA < type(uint112).max);
        vm.assume(poolB < type(uint112).max);

        // Will use reservoirB if both are empty, but don't want to test the empty pool, empty reservoir case (throws error)
        vm.assume(reservoirB > 0 || poolB > 0);

        // Ensuring we don't overflow
        vm.assume(totalLiquidity < (type(uint256).max / 2));
        vm.assume(amountInB == 0 || totalLiquidity < (type(uint256).max / 2) / amountInB);
        vm.assume(reservoirB < (type(uint256).max - poolB) - poolB);

        uint256 liquidityOut = PairMath.getDualSidedMintLiquidityOutAmount(
            totalLiquidity, amountInA, amountInB, poolA, poolB, 0, reservoirB
        );
        uint256 expectedLiquidityOut = (totalLiquidity * 2 * amountInB) / (poolB + poolB + reservoirB);
        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }

    function test_getSingleSidedMintLiquidityOutAmount(
        uint256 totalLiquidity,
        uint256 mintAmountB,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA
    ) public {
        // Pools will be capped by uint112
        vm.assume(poolA < type(uint112).max);
        vm.assume(poolB < type(uint112).max);

        // Ensure we don't divide by zero
        vm.assume(poolB > 0);
        vm.assume(poolA > 0 || reservoirA > 0);

        // Ensuring we don't overflow
        vm.assume(mintAmountB == 0 || totalLiquidity < (type(uint256).max / mintAmountB));
        vm.assume(poolA == 0 || totalLiquidity * mintAmountB < (type(uint256).max / poolA));
        vm.assume(reservoirA < type(uint256).max - poolA - poolA);
        vm.assume(poolB < type(uint256).max / (poolA + poolA + reservoirA));

        uint256 liquidityOut =
            PairMath.getSingleSidedMintLiquidityOutAmount(totalLiquidity, mintAmountB, poolA, poolB, reservoirA);
        uint256 expectedLiquidityOut = (totalLiquidity * mintAmountB * poolA) / (poolB * (poolA + poolA + reservoirA));
        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }

    function test_getDualSidedBurnOutputAmounts(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB
    ) public {
        // Ensuring we don't divide by zero
        vm.assume(totalLiquidity > 0);

        // Ensuring we don't overflow
        vm.assume(liquidityIn == 0 || totalA < type(uint256).max / liquidityIn);
        vm.assume(liquidityIn == 0 || totalB < type(uint256).max / liquidityIn);

        (uint256 amountOutA, uint256 amountOutB) =
            PairMath.getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        uint256 expectedAmountOutA = (totalA * liquidityIn) / totalLiquidity;
        uint256 expectedAmountOutB = (totalB * liquidityIn) / totalLiquidity;

        assertEq(amountOutA, expectedAmountOutA, "amountOutA does not match expectedAmountOutA");
        assertEq(amountOutB, expectedAmountOutB, "amountOutB does not match expectedAmountOutB");
    }

    function test_getSingleSidedBurnOutputAmountsUsingReservoirA(
        uint256 totalLiquidity,
        uint256 burnAmount,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA
    ) public {
        // Pools will be capped by uint112
        vm.assume(poolA < type(uint112).max);
        vm.assume(poolB < type(uint112).max);

        // Ensuring reservoirA is non-zero
        vm.assume(reservoirA > 0);

        // Ensuring we don't divide by zero
        vm.assume(totalLiquidity > 0);

        // Ensuring we don't overflow
        vm.assume(reservoirA < type(uint256).max - poolA - poolA);
        vm.assume((reservoirA + poolA + poolA) == 0 || burnAmount < type(uint256).max / (reservoirA + poolA + poolA));

        (uint256 amountOutA, uint256 amountOutB) =
            PairMath.getSingleSidedBurnOutputAmounts(totalLiquidity, burnAmount, poolA, poolB, reservoirA, 0);

        uint256 expectedAmountOutA = (burnAmount * (reservoirA + poolA + poolA)) / totalLiquidity;
        uint256 expectedAmountOutB = 0;

        assertEq(amountOutA, expectedAmountOutA, "amountOutA does not match expectedAmountOutA");
        assertEq(amountOutB, expectedAmountOutB, "amountOutB does not match expectedAmountOutB");
    }

    function test_getSingleSidedBurnOutputAmountsUsingReservoirB(
        uint256 totalLiquidity,
        uint256 burnAmount,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirB
    ) public {
        // Pools will be capped by uint112
        vm.assume(poolA < type(uint112).max);
        vm.assume(poolB < type(uint112).max);

        // Will default to reservoirB so need to check it's non-zero

        // Ensuring we don't divide by zero
        vm.assume(totalLiquidity > 0);

        // Ensuring we don't overflow
        vm.assume(reservoirB < type(uint256).max - poolB - poolB);
        vm.assume((reservoirB + poolB + poolB) == 0 || burnAmount < type(uint256).max / (reservoirB + poolB + poolB));

        (uint256 amountOutA, uint256 amountOutB) =
            PairMath.getSingleSidedBurnOutputAmounts(totalLiquidity, burnAmount, poolA, poolB, 0, reservoirB);

        uint256 expectedAmountOutA = 0;
        uint256 expectedAmountOutB = (burnAmount * (reservoirB + poolB + poolB)) / totalLiquidity;

        assertEq(amountOutA, expectedAmountOutA, "amountOutA does not match expectedAmountOutA");
        assertEq(amountOutB, expectedAmountOutB, "amountOutB does not match expectedAmountOutB");
    }

    function test_getSwapOutputAmount(uint256 inputAmount, uint256 poolInput, uint256 poolOutput) public {
        // Pools will be capped by uint112
        vm.assume(poolInput < type(uint112).max);
        vm.assume(poolOutput < type(uint112).max);

        // Ensuring we don't divide by zero
        vm.assume(poolInput > 0 || inputAmount > 0);

        // Ensuring we don't overflow
        vm.assume(inputAmount == 0 || inputAmount < type(uint256).max / 997);
        vm.assume(inputAmount == 0 || poolOutput == 0 || inputAmount < type(uint256).max / (poolOutput * 997));

        uint256 outputAmount = PairMath.getSwapOutputAmount(inputAmount, poolInput, poolOutput);
        uint256 expectedOutputAmount = (poolOutput * inputAmount * 997) / ((poolInput * 1000) + (inputAmount * 997));

        assertEq(outputAmount, expectedOutputAmount, "outputAmount does not match expectedOutputAmount");
    }

    function test_getProtocolFeeLiquidityMinted(uint256 totalLiquidity, uint256 kLast, uint256 k) public {
        // Ensuring we don't underflow
        vm.assume(kLast <= k);

        // Ensuring we don't divide by zero
        vm.assume(k != 0 || kLast != 0);

        // Ensuring we don't overflow (rootK - rootKLast will be bounded by 2^128)
        vm.assume(totalLiquidity < type(uint128).max);

        uint256 liquidityOut = PairMath.getProtocolFeeLiquidityMinted(totalLiquidity, kLast, k);

        uint256 rootKLast = Math.sqrt(kLast);
        uint256 rootK = Math.sqrt(k);
        uint256 expectedLiquidityOut = (totalLiquidity * (rootK - rootKLast)) / ((5 * rootK) + rootKLast);

        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }
}
