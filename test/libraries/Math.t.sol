// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Math} from "src/libraries/Math.sol";

contract MathTest is Test {
    function testMin(uint256 value1, uint256 value2) public {
        uint256 min = Math.min(value1, value2);
        assertLe(min, value1);
        assertLe(min, value2);
    }

    function testSqrt(uint256 root) public {
        vm.assume(root < 2 ** 128);
        assertEq(Math.sqrt(root * root), root);
    }

    function testSpecificSqrt() public {
        assertEq(Math.sqrt(0), 0);
        assertEq(Math.sqrt(1), 1);
        assertEq(Math.sqrt(2), 1);
        assertEq(Math.sqrt(3), 1);
        assertEq(Math.sqrt(4), 2);
    }
}
