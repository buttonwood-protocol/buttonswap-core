// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IButtonswapPairEvents, IButtonswapPairErrors} from "src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair} from "src/ButtonswapPair.sol";
import {Math} from "src/libraries/Math.sol";
import {MockERC20} from "mock-contracts/MockERC20.sol";
import {MockRebasingERC20} from "mock-contracts/MockRebasingERC20.sol";
import {MockUFragments} from "mock-contracts/MockUFragments.sol";
import {ICommonMockRebasingERC20} from "mock-contracts/interfaces/ICommonMockRebasingERC20.sol";
import {MockButtonswapFactory} from "test/mocks/MockButtonswapFactory.sol";
import {Utils} from "test/utils/Utils.sol";
import {PriceAssertion} from "test/utils/PriceAssertion.sol";

contract ButtonswapPairTest is Test, IButtonswapPairEvents, IButtonswapPairErrors {
    struct TestVariables {
        address zeroAddress;
        address feeToSetter;
        address feeTo;
        address minter1;
        address minter2;
        address swapper1;
        address swapper2;
        address receiver;
        address burner1;
        address burner2;
        MockButtonswapFactory factory;
        ButtonswapPair pair;
        MockERC20 token0;
        MockERC20 token1;
        ICommonMockRebasingERC20 rebasingToken0;
        ICommonMockRebasingERC20 rebasingToken1;
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;
        uint256 liquidity1;
        uint256 liquidity2;
        uint256 pool0;
        uint256 pool1;
        uint256 reservoir0;
        uint256 reservoir1;
    }

    MockERC20 public tokenA;
    MockERC20 public tokenB;
    ICommonMockRebasingERC20 public rebasingTokenA;
    ICommonMockRebasingERC20 public rebasingTokenB;
    address public userA = 0x000000000000000000000000000000000000000A;
    address public userB = 0x000000000000000000000000000000000000000b;
    address public userC = 0x000000000000000000000000000000000000000C;
    address public userD = 0x000000000000000000000000000000000000000d;
    address public userE = 0x000000000000000000000000000000000000000E;

    function getOutputAmount(uint256 inputAmount, uint256 poolInput, uint256 poolOutput)
        public
        pure
        returns (uint256)
    {
        return (poolOutput * inputAmount * 997) / ((poolInput * 1000) + (inputAmount * 997));
    }

    function assertPriceUnchanged(
        uint112 reservoir0,
        uint112 pool0Previous,
        uint112 pool1Previous,
        uint112 pool0,
        uint112 pool1
    ) public {
        // Accept the optimal new pool value to be up to 1 away from the value the contract computed
        uint112 tolerance = 1;
        bool withinTolerance;
        if (reservoir0 == 0) {
            // If reservoir0 is zero then pool0 is a fixed value, being the full token balance available
            // It is therefore pool1 that we must check is correct
            withinTolerance =
                PriceAssertion.isTermWithinTolerance(pool1, pool0, pool1Previous, pool0Previous, tolerance);
        } else {
            withinTolerance =
                PriceAssertion.isTermWithinTolerance(pool0, pool1, pool0Previous, pool1Previous, tolerance);
        }
        assertEq(withinTolerance, true, "New price outside of tolerance");
    }

    function setUp() public {
        tokenA = new MockERC20("TokenA", "TKNA");
        tokenB = new MockERC20("TokenB", "TKNB");
        // rebasingTokenA = ICommonMockRebasingERC20(address(MockRebasingERC20("TokenA", "TKNA", 18)));
        // rebasingTokenB = ICommonMockRebasingERC20(address(new MockRebasingERC20("TokenB", "TKNB", 18)));
        rebasingTokenA = ICommonMockRebasingERC20(address(new MockUFragments()));
        rebasingTokenB = ICommonMockRebasingERC20(address(new MockUFragments()));
        rebasingTokenA.initialize();
        rebasingTokenB.initialize();
    }

    function test_initialize(address factory, address token0, address token1) public {
        vm.assume(factory != address(this));

        vm.prank(factory);
        ButtonswapPair pair = new ButtonswapPair();

        assertEq(pair.factory(), factory);
        assertEq(pair.token0(), address(0));
        assertEq(pair.token1(), address(0));

        vm.prank(factory);
        pair.initialize(token0, token1);
        assertEq(pair.token0(), token0);
        assertEq(pair.token1(), token1);
        assertEq(pair.totalSupply(), 0);
        assertEq(pair.balanceOf(address(0)), 0);
        assertEq(pair.balanceOf(factory), 0);
        (uint256 pool0, uint256 pool1,) = pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = pair.getReservoirs();
        assertEq(pool0, 0);
        assertEq(pool1, 0);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
    }

    function test_initialize_CannotCallWhenNotCreator(address factory, address token0, address token1) public {
        vm.assume(factory != address(this));

        vm.prank(factory);
        ButtonswapPair pair = new ButtonswapPair();

        assertEq(pair.factory(), factory);
        assertEq(pair.token0(), address(0));
        assertEq(pair.token1(), address(0));

        vm.expectRevert(Forbidden.selector);
        pair.initialize(token0, token1);
    }

    function test_initialize_CreateViaFactory(address token0, address token1) public {
        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(token0, token1));

        assertEq(vars.pair.token0(), token0);
        assertEq(vars.pair.token1(), token1);
        assertEq(vars.pair.totalSupply(), 0);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 0);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        (uint256 pool0, uint256 pool1,) = vars.pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = vars.pair.getReservoirs();
        assertEq(pool0, 0);
        assertEq(pool1, 0);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
    }

    function test_mint_FirstMint(uint256 amount0, uint256 amount1) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(amount0 < (2 ** 112));
        vm.assume(amount1 < (2 ** 112));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount0 * amount1) > 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount0);
        vars.token1.transfer(address(vars.pair), amount1);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter1, amount0, amount1);
        uint256 liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), liquidity1 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), liquidity1);
        (uint256 pool0, uint256 pool1,) = vars.pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = vars.pair.getReservoirs();
        assertEq(pool0, amount0);
        assertEq(pool1, amount1);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
        assertEq(liquidity1, Math.sqrt(amount0 * amount1) - 1000);
    }

    function test_mint_NonRebasingSecondMint(uint256 amount00, uint256 amount01) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 to make room for the second mint
        vm.assume(amount00 < (2 ** 112) / 4);
        vm.assume(amount01 < (2 ** 112) / 4);
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Second mint needs to match same ratio as first mint
        uint256 amount10 = amount00 * 3;
        uint256 amount11 = amount01 * 3;

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        uint256 liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.transfer(address(vars.pair), amount10);
        vars.token1.transfer(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        uint256 liquidity2 = vars.pair.mint(vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), liquidity1 + liquidity2 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), liquidity2);
        (uint256 pool0, uint256 pool1,) = vars.pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = vars.pair.getReservoirs();
        assertEq(pool0, amount00 + amount10);
        assertEq(pool1, amount01 + amount11);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
        // After first mint subsequent liquidity is calculated based on ratio of value added to value already in pair
        assertEq(liquidity2, vars.pair.totalSupply() * (amount10 * 2) / (pool0 * 2));
    }

    function test_mint_CannotMintWithUnequalAmounts(
        uint256 amount00,
        uint256 amount01,
        uint256 amount10,
        uint256 amount11
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by two to make room for second mint
        vm.assume(amount00 < (2 ** 112) / 2);
        vm.assume(amount01 < (2 ** 112) / 2);
        vm.assume(amount10 < (2 ** 112) / 2);
        vm.assume(amount11 < (2 ** 112) / 2);
        // Amounts must be non-zero
        vm.assume(amount10 > 0);
        vm.assume(amount11 > 0);
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Second mint must not match price ratio
        vm.assume(amount11 != ((amount10 * amount01) / amount00));

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.transfer(address(vars.pair), amount10);
        vars.token1.transfer(address(vars.pair), amount11);
        vm.expectRevert(UnequalMint.selector);
        vars.pair.mint(vars.minter2);
        vm.stopPrank();
    }

    function test_mint_CannotFirstMintWithInsufficientLiquidity(uint256 amount0, uint256 amount1) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(amount0 < (2 ** 112));
        vm.assume(amount1 < (2 ** 112));
        // Amounts must be non-zero
        vm.assume(amount0 > 0);
        vm.assume(amount1 > 0);
        // They must also be insufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        // Use bound to avoid hitting reject cap
        uint256 min = 999 ** 2;
        uint256 max = 1001 ** 2;
        amount0 = bound(amount0, min, max);
        amount1 = bound(amount1, min / amount0, max / amount0);
        vm.assume(Math.sqrt(amount0 * amount1) == 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount0);
        vars.token1.transfer(address(vars.pair), amount1);
        vm.expectRevert(InsufficientLiquidityMinted.selector);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();
    }

    function test_mint_CannotFirstMintWithBelowMinimumLiquidity(uint256 amount0, uint256 amount1) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(amount0 < (2 ** 112));
        vm.assume(amount1 < (2 ** 112));
        // Amounts must be non-zero
        vm.assume(amount0 > 0);
        vm.assume(amount1 > 0);
        // They must also be insufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount0 * amount1) < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount0);
        vars.token1.transfer(address(vars.pair), amount1);
        vm.expectRevert(stdError.arithmeticError);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();
    }

    function test_mint_CannotSecondMintWithInsufficientLiquidity(uint256 amount00, uint256 amount01) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by two to make room for second mint
        vm.assume(amount00 < (2 ** 112) / 2);
        vm.assume(amount01 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(amount00 > 1000);
        vm.assume(amount01 > 1000);

        // Calculate the smallest second mint possible that doesn't violate price ratio
        uint256 amount10 = 1;
        uint256 amount11 = 1;
        if (amount00 < amount01) {
            amount11 = amount01 / amount00;
        } else {
            amount10 = amount00 / amount01;
        }

        // Filter for scenarios where we expect the new liquidity to dip below 1, to check the error
        vm.assume(((Math.sqrt(amount00 * amount01) * (amount11 + amount11)) / (amount01 + amount01)) == 0);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.transfer(address(vars.pair), amount10);
        vars.token1.transfer(address(vars.pair), amount11);
        vm.expectRevert(InsufficientLiquidityMinted.selector);
        vars.pair.mint(vars.minter2);
        vm.stopPrank();
    }

    function test_mint_PartialRebasingSecondMint(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 so that it can handle a second mint
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / (4 * 1000)));
        vm.assume(amount01 < (uint256(2 ** 112) / (4 * 1000)));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);
        // Sync
        vars.pair.sync();

        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);

        // Second mint needs to match new price ratio
        uint256 amount10 = vars.pool0 * 3;
        uint256 amount11 = vars.pool1 * 3;
        vm.assume(amount10 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        uint256 pool0New = vars.pool0 + amount10;
        uint256 pool1New = vars.pool1 + amount11;
        uint256 reservoir0New = vars.reservoir0;
        uint256 reservoir1New = vars.reservoir1;
        // After first mint subsequent liquidity is calculated based on ratio of value added to value already in pair
        uint256 liquidityNew;
        {
            uint256 reservoir0InTermsOf1 = (vars.reservoir0 * vars.pool1) / vars.pool0;
            liquidityNew =
                vars.pair.totalSupply() * (amount11 * 2) / ((vars.pool1 * 2) + vars.reservoir1 + reservoir0InTermsOf1);
        }

        vm.startPrank(vars.minter2);
        vars.rebasingToken0.transfer(address(vars.pair), amount10);
        vars.token1.transfer(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mint(vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        // There should be no fee collected on balance increases that occur outside of a swap
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        assertEq(vars.pool0, pool0New, "pool0");
        assertEq(vars.pool1, pool1New, "pool1");
        assertEq(vars.reservoir0, reservoir0New, "reservoir0");
        assertEq(vars.reservoir1, reservoir1New, "reservoir1");
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
    }

    function test_mint_FullRebasingSecondMint(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 so that it can handle a second mint
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / (4 * 1000)));
        vm.assume(amount01 < (uint256(2 ** 112) / (4 * 1000)));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        // @TODO test does not currently work due to bug in contract where fee is collected on rebases, not only swaps
        //        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vm.assume(amount01 < vars.rebasingToken1.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.rebasingToken1.mint(vars.minter1, amount01);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), amount00);
        vars.rebasingToken1.transfer(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);
        // Sync
        vars.pair.sync();

        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);

        // Second mint needs to match new price ratio
        uint256 amount10 = vars.pool0 * 3;
        uint256 amount11 = vars.pool1 * 3;
        vm.assume(amount10 < vars.rebasingToken0.mintableBalance());
        vm.assume(amount11 < vars.rebasingToken1.mintableBalance());
        vars.rebasingToken0.mint(vars.minter2, amount10);
        vars.rebasingToken1.mint(vars.minter2, amount11);

        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        uint256 pool0New = vars.pool0 + amount10;
        uint256 pool1New = vars.pool1 + amount11;
        uint256 reservoir0New = vars.reservoir0;
        uint256 reservoir1New = vars.reservoir1;
        // After first mint subsequent liquidity is calculated based on ratio of value added to value already in pair
        uint256 liquidityNew;
        {
            uint256 reservoir0InTermsOf1 = (vars.reservoir0 * vars.pool1) / vars.pool0;
            liquidityNew =
                vars.pair.totalSupply() * (amount11 * 2) / ((vars.pool1 * 2) + vars.reservoir1 + reservoir0InTermsOf1);
        }
        vm.assume(liquidityNew > 0);

        vm.startPrank(vars.minter2);
        vars.rebasingToken0.transfer(address(vars.pair), amount10);
        vars.rebasingToken1.transfer(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mint(vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000, "totalSupply");
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        // There should be no fee collected on balance increases that occur outside of a swap
        // @TODO test does not currently work due to bug in contract where fee is collected on rebases, not only swaps
        //        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        assertEq(vars.pool0, pool0New, "pool0");
        assertEq(vars.pool1, pool1New, "pool1");
        assertEq(vars.reservoir0, reservoir0New, "reservoir0");
        assertEq(vars.reservoir1, reservoir1New, "reservoir1");
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
    }

    function test_burn(uint256 mintAmount0, uint256 mintAmount1, uint256 burnAmount) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(burnAmount < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        vm.assume(burnAmount > 0);
        // Expected token amounts out must be non-zero
        uint256 pairTotalSupply = Math.sqrt(mintAmount0 * mintAmount1);
        uint256 expectedAmount0 = (mintAmount0 * burnAmount) / pairTotalSupply;
        uint256 expectedAmount1 = (mintAmount1 * burnAmount) / pairTotalSupply;
        // 1000 liquidity sent to zero address
        vm.assume(burnAmount <= (pairTotalSupply - 1000));
        vm.assume(expectedAmount0 > 0);
        vm.assume(expectedAmount1 > 0);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        pairTotalSupply = vars.pair.totalSupply();

        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectEmit(true, true, true, true);
        emit Burn(vars.minter1, expectedAmount0, expectedAmount1, vars.receiver);
        (uint256 amount0, uint256 amount1) = vars.pair.burn(vars.receiver);
        vm.stopPrank();

        assertEq(amount0, expectedAmount0);
        assertEq(amount1, expectedAmount1);
        assertEq(vars.token0.balanceOf(vars.receiver), expectedAmount0);
        assertEq(vars.token1.balanceOf(vars.receiver), expectedAmount1);
        assertEq(vars.pair.totalSupply(), pairTotalSupply - burnAmount);
    }

    function test_burn_CannotCallWithInsufficientLiquidityBurned(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 burnAmount
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(burnAmount < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Expected token amounts out must be non-zero
        uint256 pairTotalSupply = Math.sqrt(mintAmount0 * mintAmount1);
        uint256 expectedAmount0 = (mintAmount0 * burnAmount) / pairTotalSupply;
        uint256 expectedAmount1 = (mintAmount1 * burnAmount) / pairTotalSupply;
        // 1000 liquidity sent to zero address
        vm.assume(burnAmount <= (pairTotalSupply - 1000));
        vm.assume(expectedAmount0 == 0 || expectedAmount1 == 0);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectRevert(InsufficientLiquidityBurned.selector);
        vars.pair.burn(vars.receiver);
        vm.stopPrank();
    }

    function test_sync_CannotSyncBeforeFirstMint(address syncer) public {
        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));

        vm.prank(syncer);
        vm.expectRevert(Uninitialized.selector);
        vars.pair.sync();
    }

    function test_sync_NonRebasing(uint256 mintAmount0, uint256 mintAmount1, address syncer) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        vm.prank(syncer);
        // Expect no changes since there's no rebasing
        vm.expectEmit(true, true, true, true);
        emit SyncReservoir(uint112(reservoir0), uint112(reservoir1));
        vars.pair.sync();

        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1);
    }

    function test_sync_PartialRebasing(
        uint256 mintAmount0,
        uint256 mintAmount1,
        address syncer,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(mintAmount0 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        // Apply rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        vm.prank(syncer);
        // Predicting final pool and reservoir values is too complex to test
        vm.expectEmit(false, false, false, false);
        emit Sync(0, 0);
        vm.expectEmit(false, false, false, false);
        emit SyncReservoir(0, 0);
        vars.pair.sync();

        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1);
    }

    function test_sync_FullRebasing(
        uint256 mintAmount0,
        uint256 mintAmount1,
        address syncer,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 111));
        vm.assume(mintAmount1 < (2 ** 111));
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(mintAmount0 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vm.assume(mintAmount1 <= vars.rebasingToken1.mintableBalance());
        vars.rebasingToken1.mint(vars.minter1, mintAmount1);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.rebasingToken1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        // Apply rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);

        vm.prank(syncer);
        // Predicting final pool and reservoir values is too complex to test
        vm.expectEmit(false, false, false, false);
        emit Sync(0, 0);
        vm.expectEmit(false, false, false, false);
        emit SyncReservoir(0, 0);
        vars.pair.sync();

        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1);
    }

    function test_sync_FullRebasingAfterNonEmptyReservoir(
        uint256 mintAmount0,
        uint256 mintAmount1,
        address syncer,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 111));
        vm.assume(mintAmount1 < (2 ** 111));
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(mintAmount0 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vm.assume(mintAmount1 <= vars.rebasingToken1.mintableBalance());
        vars.rebasingToken1.mint(vars.minter1, mintAmount1);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.rebasingToken1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Apply first rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);

        // Do first sync
        vm.prank(syncer);
        vars.pair.sync();

        // One reservoir should be non-zero now
        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        // Filter out fuzzed input that didn't rebase
        vm.assume(reservoir0 != 0 || reservoir1 != 0);
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        // Apply second rebase
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);

        // Do second sync starting from non-empty reservoir state
        vm.prank(syncer);
        // Predicting final pool and reservoir values is too complex to test
        vm.expectEmit(false, false, false, false);
        emit Sync(0, 0);
        vm.expectEmit(false, false, false, false);
        emit SyncReservoir(0, 0);
        vars.pair.sync();

        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1);
    }
}
