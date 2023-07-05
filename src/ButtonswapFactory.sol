// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {IButtonswapFactory} from "./interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapPair} from "./interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair} from "./ButtonswapPair.sol";

contract ButtonswapFactory is IButtonswapFactory {
    /**
     * @inheritdoc IButtonswapFactory
     */
    address public feeTo;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address public feeToSetter;

    /**
     * @inheritdoc IButtonswapFactory
     */
    mapping(address => mapping(address => address)) public getPair;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address[] public allPairs;

    address internal lastToken0;

    address internal lastToken1;

    /**
     * @inheritdoc IButtonswapFactory
     */
    bool public isCreationRestricted;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address public isCreationRestrictedSetter;

    /**
     * @inheritdoc IButtonswapFactory
     */
    address public isPausedSetter;

    /**
     * @dev `feeTo` is not initialised during deployment, and must be set separately by a call to {setFeeTo}.
     * @param _feeToSetter The account that has the ability to set `feeToSetter` and `feeTo`
     * @param _isCreationRestrictedSetter The account that has the ability to set `isCreationRestrictedSetter` and `isCreationRestricted`
     */
    constructor(address _feeToSetter, address _isCreationRestrictedSetter, address _isPausedSetter) {
        feeToSetter = _feeToSetter;
        isCreationRestrictedSetter = _isCreationRestrictedSetter;
        isPausedSetter = _isPausedSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function allPairsLength() external view returns (uint256 count) {
        count = allPairs.length;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (isCreationRestricted && msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        if (tokenA == tokenB) {
            revert TokenIdenticalAddress();
        }
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert TokenZeroAddress();
        }
        // single check is sufficient
        if (getPair[token0][token1] != address(0)) {
            revert PairExists();
        }
        lastToken0 = token0;
        lastToken1 = token1;
        bytes memory bytecode = type(ButtonswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // Resetting lastToken0/lastToken1 to 0 to refund gas
        lastToken0 = address(0);
        lastToken1 = address(0);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) {
            revert Forbidden();
        }
        feeTo = _feeTo;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) {
            revert Forbidden();
        }
        feeToSetter = _feeToSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsCreationRestricted(bool _isCreationRestricted) external {
        if (msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        isCreationRestricted = _isCreationRestricted;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsCreationRestrictedSetter(address _isCreationRestrictedSetter) external {
        if (msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        isCreationRestrictedSetter = _isCreationRestrictedSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsPausedSetter(address _isPausedSetter) external {
        if (msg.sender != isPausedSetter) {
            revert Forbidden();
        }
        isPausedSetter = _isPausedSetter;
    }

    /**
     * @inheritdoc IButtonswapFactory
     */
    function setIsPaused(address[] calldata pairs, bool isPausedNew) external {
        if (msg.sender != isPausedSetter) {
            revert Forbidden();
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            IButtonswapPair(pairs[i]).setIsPaused(isPausedNew);
        }
    }

    function lastCreatedPairTokens() external view returns (address token0, address token1) {
        token0 = lastToken0;
        token1 = lastToken1;
    }
}
