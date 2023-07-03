// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "buttonswap-core_forge-std/Test.sol";
import {
    IButtonswapFactoryEvents,
    IButtonswapFactoryErrors
} from "../src/interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapPair} from "../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapFactory} from "../src/ButtonswapFactory.sol";
import {Utils} from "./utils/Utils.sol";

contract ButtonswapFactoryTest is Test, IButtonswapFactoryEvents, IButtonswapFactoryErrors {
    struct Tokens {
        address A;
        address B;
        address _0;
        address _1;
    }

    function getTokens(address tokenA, address tokenB) internal pure returns (Tokens memory) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Tokens memory tokens;
        tokens.A = tokenA;
        tokens.B = tokenB;
        tokens._0 = token0;
        tokens._1 = token1;
        return tokens;
    }

    function test_createPair(
        address initialFeeToSetter,
        address token0A,
        address token0B,
        address token1A,
        address token1B,
        address token2A
    ) public {
        vm.assume(initialFeeToSetter != address(this));

        // Ensure fuzzed addresses are all non-zero
        vm.assume(token0A != address(0));
        vm.assume(token0B != address(0));
        vm.assume(token1A != address(0));
        vm.assume(token1B != address(0));
        vm.assume(token2A != address(0));

        // Ensure fuzzed addresses are all distinct
        vm.assume(token0A != token0B);
        vm.assume(token0A != token1A);
        vm.assume(token0A != token1B);
        vm.assume(token0A != token2A);

        vm.assume(token0B != token1A);
        vm.assume(token0B != token1B);
        vm.assume(token0B != token2A);

        vm.assume(token1A != token1B);
        vm.assume(token1A != token2A);

        vm.assume(token1B != token2A);

        // Calculate sorted token pairs
        Tokens memory tokens0 = getTokens(token0A, token0B);
        Tokens memory tokens1 = getTokens(token1A, token1B);
        // Share B token to confirm pair creation works
        Tokens memory tokens2 = getTokens(token2A, token1B);

        // Two factories so we can test that token param order doesn't matter
        ButtonswapFactory buttonswapFactory1 = new ButtonswapFactory(initialFeeToSetter);
        ButtonswapFactory buttonswapFactory2 = new ButtonswapFactory(initialFeeToSetter);

        assertEq(buttonswapFactory1.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory1.allPairs(0);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), address(0));
        vm.expectRevert();
        buttonswapFactory1.allPairs(1);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory1.allPairs(2);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), address(0));

        assertEq(buttonswapFactory2.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory2.allPairs(0);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), address(0));
        vm.expectRevert();
        buttonswapFactory2.allPairs(1);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory2.allPairs(2);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), address(0));

        // Ideally confirm event params on all but pair address but invalid final param doesn't fail test as expected
        //   so best indicate we're not checking it instead.
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens0._0, tokens0._1, address(0), 1);
        address pair10 = buttonswapFactory1.createPair(tokens0.A, tokens0.B);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens0._0, tokens0._1, address(0), 1);
        address pair20 = buttonswapFactory2.createPair(tokens0.B, tokens0.A);

        assertTrue(pair10 != pair20);
        assertEq(IButtonswapPair(pair10).token0(), tokens0._0);
        assertEq(IButtonswapPair(pair10).token1(), tokens0._1);
        assertEq(IButtonswapPair(pair20).token0(), tokens0._0);
        assertEq(IButtonswapPair(pair20).token1(), tokens0._1);

        assertEq(buttonswapFactory1.allPairsLength(), 1);
        assertEq(buttonswapFactory1.allPairs(0), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), pair10);
        vm.expectRevert();
        buttonswapFactory1.allPairs(1);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory1.allPairs(2);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), address(0));

        assertEq(buttonswapFactory2.allPairsLength(), 1);
        assertEq(buttonswapFactory2.allPairs(0), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), pair20);
        vm.expectRevert();
        buttonswapFactory2.allPairs(1);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory2.allPairs(2);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), address(0));

        // Test that creating a second pair behaves as expected
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens1._0, tokens1._1, address(0), 2);
        address pair11 = buttonswapFactory1.createPair(tokens1.A, tokens1.B);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens1._0, tokens1._1, address(0), 2);
        address pair21 = buttonswapFactory2.createPair(tokens1.B, tokens1.A);

        assertTrue(pair11 != pair21);
        assertEq(IButtonswapPair(pair11).token0(), tokens1._0);
        assertEq(IButtonswapPair(pair11).token1(), tokens1._1);
        assertEq(IButtonswapPair(pair21).token0(), tokens1._0);
        assertEq(IButtonswapPair(pair21).token1(), tokens1._1);

        assertEq(buttonswapFactory1.allPairsLength(), 2);
        assertEq(buttonswapFactory1.allPairs(0), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), pair10);
        assertEq(buttonswapFactory1.allPairs(1), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), pair11);
        vm.expectRevert();
        buttonswapFactory1.allPairs(2);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), address(0));

        assertEq(buttonswapFactory2.allPairsLength(), 2);
        assertEq(buttonswapFactory2.allPairs(0), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), pair20);
        assertEq(buttonswapFactory2.allPairs(1), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), pair21);
        vm.expectRevert();
        buttonswapFactory2.allPairs(2);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), address(0));

        // Test that creating a third pair, which shares a token with a previous pair, behaves as expected
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens2._0, tokens2._1, address(0), 3);
        address pair12 = buttonswapFactory1.createPair(tokens2.A, tokens2.B);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens2._0, tokens2._1, address(0), 3);
        address pair22 = buttonswapFactory2.createPair(tokens2.B, tokens2.A);

        assertTrue(pair12 != pair22);
        assertEq(IButtonswapPair(pair12).token0(), tokens2._0);
        assertEq(IButtonswapPair(pair12).token1(), tokens2._1);
        assertEq(IButtonswapPair(pair22).token0(), tokens2._0);
        assertEq(IButtonswapPair(pair22).token1(), tokens2._1);

        assertEq(buttonswapFactory1.allPairsLength(), 3);
        assertEq(buttonswapFactory1.allPairs(0), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), pair10);
        assertEq(buttonswapFactory1.allPairs(1), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), pair11);
        assertEq(buttonswapFactory1.allPairs(2), pair12);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), pair12);
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), pair12);

        assertEq(buttonswapFactory2.allPairsLength(), 3);
        assertEq(buttonswapFactory2.allPairs(0), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), pair20);
        assertEq(buttonswapFactory2.allPairs(1), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), pair21);
        assertEq(buttonswapFactory2.allPairs(2), pair22);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), pair22);
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), pair22);
    }

    function test_createPair_CannotCreatePairWithIdenticalTokens(address initialFeeToSetter, address token) public {
        vm.assume(initialFeeToSetter != address(this));
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);

        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, token), address(0));

        vm.expectRevert(TokenIdenticalAddress.selector);
        address pair = buttonswapFactory.createPair(token, token);

        assertEq(pair, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, token), address(0));
    }

    function test_createPair_CannotCreatePairWithZeroAddressTokens(address initialFeeToSetter, address token) public {
        vm.assume(initialFeeToSetter != address(this));
        // Ensure fuzzed address is non-zero
        vm.assume(token != address(0));
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);

        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, address(0)), address(0));

        vm.expectRevert(TokenZeroAddress.selector);
        address pair1 = buttonswapFactory.createPair(token, address(0));

        assertEq(pair1, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, address(0)), address(0));

        // Test it with the zero address as the other parameter
        vm.expectRevert(TokenZeroAddress.selector);
        address pair2 = buttonswapFactory.createPair(address(0), token);

        assertEq(pair2, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, address(0)), address(0));
    }

    function test_createPair_CannotCreatePairThatWasAlreadyCreated(
        address initialFeeToSetter,
        address tokenA,
        address tokenB
    ) public {
        vm.assume(initialFeeToSetter != address(this));
        // Ensure fuzzed addresses are non-zero
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        // Ensure fuzzed addresses are not identical
        vm.assume(tokenA != tokenB);
        // Calculate sorted token pairs
        Tokens memory tokens = getTokens(tokenA, tokenB);
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);

        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(tokens.A, tokens.B), address(0));

        // First creation should succeed
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens._0, tokens._1, address(0), 1);
        address pair1 = buttonswapFactory.createPair(tokens.A, tokens.B);

        assertTrue(pair1 != address(0));
        assertEq(IButtonswapPair(pair1).token0(), tokens._0);
        assertEq(IButtonswapPair(pair1).token1(), tokens._1);
        assertEq(buttonswapFactory.allPairsLength(), 1);
        assertEq(buttonswapFactory.allPairs(0), pair1);
        assertEq(buttonswapFactory.getPair(tokens.A, tokens.B), pair1);

        // Try to create the pair again
        vm.expectRevert(PairExists.selector);
        address pair2 = buttonswapFactory.createPair(tokens.A, tokens.B);

        assertEq(pair2, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 1);
        vm.expectRevert();
        buttonswapFactory.allPairs(1);

        // Try to create the pair again, but with token params swapped order
        vm.expectRevert(PairExists.selector);
        address pair3 = buttonswapFactory.createPair(tokens.B, tokens.A);

        assertEq(pair3, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 1);
        vm.expectRevert();
        buttonswapFactory.allPairs(1);
    }

    function test_createPair_CannotCreatePairIfCreationLockedAndNotFeeToSetter(
        address initialFeeToSetter,
        address pairCreator,
        address tokenA,
        address tokenB
    ) public {
        vm.assume(pairCreator != initialFeeToSetter);
        // Ensure fuzzed addresses are non-zero
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        // Ensure fuzzed addresses are not identical
        vm.assume(tokenA != tokenB);
        // Calculate sorted token pairs
        Tokens memory tokens = getTokens(tokenA, tokenB);
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);

        // FeeToSetter locking pair creation
        vm.prank(initialFeeToSetter);
        buttonswapFactory.setIsCreationRestricted(true);

        // PairCreator attempting to create pair
        vm.startPrank(pairCreator);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.createPair(tokens.A, tokens.B);
        vm.stopPrank();
    }

    function test_createPair_FeeToSetterCanCreatePairIfCreationLocked(
        address initialFeeToSetter,
        address tokenA,
        address tokenB
    ) public {
        // Ensure fuzzed addresses are non-zero
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        // Ensure fuzzed addresses are not identical
        vm.assume(tokenA != tokenB);
        // Calculate sorted token pairs
        Tokens memory tokens = getTokens(tokenA, tokenB);
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);

        // FeeToSetter locking pair creation
        vm.prank(initialFeeToSetter);
        buttonswapFactory.setIsCreationRestricted(true);

        // FeeToSetter can create pair
        vm.startPrank(initialFeeToSetter);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens._0, tokens._1, address(0), 1);
        buttonswapFactory.createPair(tokens.A, tokens.B);
        vm.stopPrank();
    }

    function test_setFeeTo(address initialFeeToSetter, address feeTo) public {
        vm.assume(initialFeeToSetter != address(this));
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);
        assertEq(buttonswapFactory.feeTo(), address(0));

        vm.prank(initialFeeToSetter);
        buttonswapFactory.setFeeTo(feeTo);
        assertEq(buttonswapFactory.feeTo(), feeTo);
    }

    function test_setFeeTo_CannotCallWhenNotFeeSetter(address initialFeeToSetter, address feeTo) public {
        vm.assume(initialFeeToSetter != address(this));
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);
        assertEq(buttonswapFactory.feeTo(), address(0));

        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setFeeTo(feeTo);
        assertEq(buttonswapFactory.feeTo(), address(0));
    }

    function test_setFeeToSetter(address initialFeeToSetter, address newFeeToSetter) public {
        vm.assume(initialFeeToSetter != address(this));
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);
        assertEq(buttonswapFactory.feeToSetter(), initialFeeToSetter);

        vm.prank(initialFeeToSetter);
        buttonswapFactory.setFeeToSetter(newFeeToSetter);
        assertEq(buttonswapFactory.feeToSetter(), newFeeToSetter);
    }

    function test_setFeeToSetter_CannotCallWhenNotFeeSetter(address initialFeeToSetter, address newFeeToSetter)
        public
    {
        vm.assume(initialFeeToSetter != address(this));
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);
        assertEq(buttonswapFactory.feeToSetter(), initialFeeToSetter);

        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setFeeToSetter(newFeeToSetter);
        assertEq(buttonswapFactory.feeToSetter(), initialFeeToSetter);
    }

    // If isPaused is true, then new pairs are created paused
    function test_setIsPaused_onlyFeeToSetterCanCall(
        address initialFeeToSetter,
        address setIsPausedCaller,
        address tokenA,
        address tokenB,
        bool isPausedNew
    ) public {
        vm.assume(initialFeeToSetter != address(this));
        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory = new ButtonswapFactory(initialFeeToSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        if (setIsPausedCaller != initialFeeToSetter) {
            vm.startPrank(setIsPausedCaller);
            vm.expectRevert(Forbidden.selector);
            buttonswapFactory.setIsPaused(pairAddresses, isPausedNew);
        } else {
            vm.startPrank(setIsPausedCaller);
            buttonswapFactory.setIsPaused(pairAddresses, isPausedNew);
            assertEq(IButtonswapPair(pairAddress).getIsPaused(), isPausedNew, "isPaused should have updated");
        }
        vm.stopPrank();
    }
}
