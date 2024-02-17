// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {Deploy} from "../script/Deploy.s.sol";
import {ButtonswapFactory} from "../src/ButtonswapFactory.sol";
import {Test} from "buttonswap-core_forge-std/Test.sol";

contract DeployTest is Test {
    Deploy public deploy;

    function setUp() public {
        deploy = new Deploy();
    }

    function test_setup() public {
        ButtonswapFactory buttonswapFactory = deploy.run();
        assertNotEq(address(buttonswapFactory), address(0), "Validating ButtonswapFactory deploys with no errors");
    }
}
