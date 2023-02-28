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

    function setUp() public {
        tokenA = new MockERC20("TokenA", "TKNA");
        tokenB = new MockERC20("TokenB", "TKNB");
        // rebasingTokenA = new MockRebasingERC20("TokenA", "TKNA", 18);
        // rebasingTokenB = new MockRebasingERC20("TokenB", "TKNB", 18);
        rebasingTokenA = ICommonMockRebasingERC20(address(new MockUFragments()));
        rebasingTokenB = ICommonMockRebasingERC20(address(new MockUFragments()));
    }

    function testInitialize(address factory, address token0, address token1) public {
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

    function testCannotInitializeWhenNotCreator(address factory, address token0, address token1) public {
        vm.assume(factory != address(this));

        vm.prank(factory);
        ButtonswapPair pair = new ButtonswapPair();

        assertEq(pair.factory(), factory);
        assertEq(pair.token0(), address(0));
        assertEq(pair.token1(), address(0));

        vm.expectRevert(Forbidden.selector);
        pair.initialize(token0, token1);
    }

    function testCreateViaFactory(address token0, address token1) public {
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
}
