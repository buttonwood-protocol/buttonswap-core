// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./Base.s.sol";
import {ButtonswapFactory} from "../src/ButtonswapFactory.sol";

contract Deploy is BaseScript {
    function run() public virtual broadcast returns (ButtonswapFactory buttonswapFactory) {
        address _feeToSetter = 0xb1Cc73B1610863D51B5b8269b9162237e87679c3;
        address _isCreationRestrictedSetter = 0xb1Cc73B1610863D51B5b8269b9162237e87679c3;
        address _isPausedSetter = 0xb1Cc73B1610863D51B5b8269b9162237e87679c3;
        address _paramSetter = 0xb1Cc73B1610863D51B5b8269b9162237e87679c3;
        string memory _tokenName = "Mission LP Token V1";
        string memory _tokenSymbol = "MSSN-V1";
        buttonswapFactory = new ButtonswapFactory(
            _feeToSetter, _isCreationRestrictedSetter, _isPausedSetter, _paramSetter, _tokenName, _tokenSymbol
        );
    }
}
