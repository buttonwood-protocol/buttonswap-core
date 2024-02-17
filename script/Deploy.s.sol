// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./Base.s.sol";
import {ButtonswapFactory} from "../src/ButtonswapFactory.sol";

contract Deploy is BaseScript {
    function run() public virtual broadcast returns (ButtonswapFactory buttonswapFactory) {
        address _feeToSetter = 0x0000000000000000000000000000000000000000;
        address _isCreationRestrictedSetter = 0x0000000000000000000000000000000000000000;
        address _isPausedSetter = 0x0000000000000000000000000000000000000000;
        address _paramSetter = 0x0000000000000000000000000000000000000000;
        string memory _tokenName = "Buttonswap LP Token V1";
        string memory _tokenSymbol = "BSWP-V1";
        buttonswapFactory = new ButtonswapFactory(
            _feeToSetter, _isCreationRestrictedSetter, _isPausedSetter, _paramSetter, _tokenName, _tokenSymbol
        );
    }
}
