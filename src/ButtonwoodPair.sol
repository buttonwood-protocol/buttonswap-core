// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import "./interfaces/IButtonwoodPair.sol";
import "./ButtonwoodERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IButtonwoodFactory.sol";
import "./interfaces/IButtonwoodCallee.sol";

contract ButtonwoodPair is IButtonwoodPair, ButtonwoodERC20 {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    uint112 private pool0; // uses single storage slot, accessible via getPools
    uint112 private pool1; // uses single storage slot, accessible via getPools
    uint112 private reservoir0; // uses single storage slot, accessible via getReservoirs
    uint112 private reservoir1; // uses single storage slot, accessible via getReservoirs
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getPools

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // pool0 * pool1, as of immediately after the most recent liquidity event

    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, "Buttonwood: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getPools() public view returns (uint112 _pool0, uint112 _pool1, uint32 _blockTimestampLast) {
        _pool0 = pool0;
        _pool1 = pool1;
        _blockTimestampLast = blockTimestampLast;
    }

    function getReservoirs() public view returns (uint112 _reservoir0, uint112 _reservoir1) {
        _reservoir0 = reservoir0;
        _reservoir1 = reservoir1;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Buttonwood: TRANSFER_FAILED");
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "Buttonwood: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update pools and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _pool0, uint112 _pool1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Buttonwood: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _pool0 != 0 && _pool1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint256(UQ112x112.encode(_pool1).uqdiv(_pool0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_pool0).uqdiv(_pool1)) * timeElapsed;
        }
        pool0 = uint112(balance0);
        pool1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(pool0, pool1);
    }

    // update pools and reservoirs to the given values
    function _updateReservoirs(
        uint112 previousPool0,
        uint112 previousPool1,
        uint256 newPool0,
        uint256 newPool1,
        uint256 newReservoir0,
        uint256 newReservoir1
    ) private {
        require(
            newPool0 <= type(uint112).max && newPool1 <= type(uint112).max && newReservoir0 <= type(uint112).max
                && newReservoir1 <= type(uint112).max,
            "Buttonwood: OVERFLOW"
        );

        // invariant should always hold: at least one of reservoir0 and reservoir1 is equal to 0
        require(newReservoir0 == 0 || newReservoir1 == 0, "Buttonwood: Reservoir invariant");

        reservoir0 = uint112(newReservoir0);
        reservoir1 = uint112(newReservoir1);
        _update(newPool0, newPool1, previousPool0, previousPool1);
        emit SyncReservoir(reservoir0, reservoir1);
    }

    // Get the pool and reservoir updates given the new balance and previous pools and reservoirs
    // New updated values should include the full balance in (pool + reservoir) and maintain the same marginal price as before.
    function _getNewStoredBalances(
        uint256 balance,
        uint256 pool,
        uint256 otherPool,
        uint256 reservoir,
        uint256 otherReservoir
    ) private pure returns (uint256 newPool, uint256 newReservoir, uint256 newOtherPool, uint256 newOtherReservoir) {
        newPool = pool;
        newReservoir = reservoir;
        newOtherPool = otherPool;
        newOtherReservoir = otherReservoir;
        uint256 totalStored = newPool.add(newReservoir);
        if (balance == totalStored) {
            return (newPool, newReservoir, newOtherPool, newOtherReservoir);
        }

        if (balance > totalStored) {
            // balance increased, so we send the extra tokens to the reservoir
            newReservoir = newReservoir.add(balance.sub(totalStored));
        } else {
            uint256 delta = totalStored.sub(balance);
            // balance decreased, and we have enough in the reservoir to cover it
            if (reservoir > delta) {
                newReservoir = newReservoir.sub(delta);
            } else {
                if (reservoir > 0) {
                    delta = delta.sub(reservoir);
                    newReservoir = 0;
                }

                if (delta > 0) {
                    // balance decreased, so we send some of the other token to the reservoir make up for it
                    uint256 offset = (otherPool.mul(delta)) / newPool;

                    newPool = balance;
                    newOtherPool = newOtherPool.sub(offset);
                    newOtherReservoir = newOtherReservoir.add(offset);
                }
            }
        }
    }

    // update pools and reservoirs, ensuring that the marginal price remains the same
    // The updated values should have the following invariants:
    //  - (pool + reservoir) == balance for each token.
    //  - At least one of the reservoirs should have 0 tokens. In other words we maximize the number of tokens in the pools.
    //  - The marginal prices should be the same before the updates as after
    function _syncReservoirs(
        uint256 balance0,
        uint256 balance1,
        uint112 _pool0,
        uint112 _pool1,
        uint112 _reservoir0,
        uint112 _reservoir1
    ) private {
        require(_pool0 > uint112(0) && _pool1 > uint112(0), "Buttonwood: Uninitialized");
        uint256 newPool0 = uint256(_pool0);
        uint256 newPool1 = uint256(_pool1);
        uint256 newReservoir0 = uint256(_reservoir0);
        uint256 newReservoir1 = uint256(_reservoir1);

        (newPool0, newReservoir0, newPool1, newReservoir1) =
            _getNewStoredBalances(balance0, newPool0, newPool1, newReservoir0, newReservoir1);
        (newPool1, newReservoir1, newPool0, newReservoir0) =
            _getNewStoredBalances(balance1, newPool1, newPool0, newReservoir1, newReservoir0);

        if (newReservoir0 > 0 && newReservoir1 > 0) {
            // both reservoirs have funds, so we can move some from each back to the main pool
            uint256 reservoir0InTermsOf1 = (newPool1.mul(newReservoir0)) / newPool0;
            uint256 reservoir1InTermsOf0 = (newPool0.mul(newReservoir1)) / newPool1;

            if (reservoir0InTermsOf1 <= newReservoir1) {
                // then we can drain reservoir0 and have some (or none) remaining in reservoir1
                newPool0 = newPool0.add(newReservoir0);
                newPool1 = newPool1.add(reservoir0InTermsOf1);
                newReservoir0 = 0;
                newReservoir1 = newReservoir1.sub(reservoir0InTermsOf1);
            } else {
                // then we can drain reservoir1 and have some remaining in reservoir0
                newPool1 = newPool1.add(newReservoir1);
                newPool0 = newPool0.add(reservoir1InTermsOf0);
                newReservoir1 = 0;
                newReservoir0 = newReservoir0.sub(reservoir1InTermsOf0);
            }
        }

        require(newPool0.add(newReservoir0) == balance0, "Buttonwood: Token0 Balance Mismatch");
        require(newPool1.add(newReservoir1) == balance1, "Buttonwood: Token1 Balance Mismatch");
        _updateReservoirs(pool0, _pool1, newPool0, newPool1, newReservoir0, newReservoir1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _pool0, uint112 _pool1) private returns (bool feeOn) {
        address feeTo = IButtonwoodFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_pool0).mul(_pool1));
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint256 _pool0, uint256 _pool1,) = getPools(); // gas savings
        (uint256 _reservoir0, uint256 _reservoir1) = getReservoirs(); // gas savings
        uint256 amount0 = IERC20(token0).balanceOf(address(this)).sub(_pool0).sub(_reservoir0);
        uint256 amount1 = IERC20(token1).balanceOf(address(this)).sub(_pool1).sub(_reservoir1);
        bool feeOn = _mintFee(uint112(_pool0), uint112(_pool1));

        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            uint256 value0AddedInTermsOf1 = (_pool1.mul(amount0)) / _pool0;
            require(value0AddedInTermsOf1 == amount1, "Buttonwood: UNEQUAL_MINT");
            uint256 reservoir0InTermfOf1 = (_pool1.mul(_reservoir0)) / _pool0;

            // liquidity minted in proportion to the total value added in terms of token1
            // divided by the total value in the pools + reservoirs in terms of 1
            // note: we could calculate this in terms of token0 and get the same result
            liquidity =
                _totalSupply.mul(amount1.add(amount1)) / (_pool1.add(_pool1).add(reservoir0InTermfOf1).add(_reservoir1));
        }

        require(liquidity > 0, "Buttonwood: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(_pool0.add(amount0), _pool1.add(amount1), uint112(_pool0), uint112(_pool1));
        if (feeOn) kLast = uint256(pool0).mul(pool1); // pool0 and pool1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mintWithReservoir(address to) external lock returns (uint256 liquidity) {
        (uint112 _pool0, uint112 _pool1,) = getPools(); // gas savings
        (uint256 newReservoir0, uint256 newReservoir1) = getReservoirs(); // gas savings
        uint256 newPool0 = uint256(_pool0);
        uint256 newPool1 = uint256(_pool1);
        uint256 amount0 = IERC20(token0).balanceOf(address(this)).sub(newPool0).sub(newReservoir0);
        uint256 amount1 = IERC20(token1).balanceOf(address(this)).sub(newPool1).sub(newReservoir1);
        require(amount0 == 0 || amount1 == 0, "Buttonwood: TWO_SIDED_RESERVOIR_MINT");
        require(amount0 > 0 || amount1 > 0, "Buttonwood: INSUFFICIENT_LIQUIDITY_ADDED");

        bool feeOn = _mintFee(_pool0, _pool1);

        {
            uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
            require(_totalSupply > 0, "Buttonwood: Uninitialized");

            // Depending on which token liquidity was added for,
            // try to pull funds out of the other token's reservoir to match
            if (amount0 > 0) {
                // liquidity is a proportion of value added over existing pool value
                liquidity =
                    _totalSupply.mul(newPool1.mul(amount0)) / (newPool1.add(newPool1).add(newReservoir1).mul(newPool0));

                uint256 value0AddedInTermsOf1 = (newPool1.mul(amount0)) / newPool0;
                require(newReservoir1 >= value0AddedInTermsOf1, "Buttonwood: INSUFFICIENT_RESERVOIR");

                // take from reservoir1 to make up for the missing value added
                newReservoir1 = newReservoir1.sub(value0AddedInTermsOf1);
                newPool1 = newPool1.add(value0AddedInTermsOf1);
            } else {
                // liquidity is a proportion of value added over existing pool value
                liquidity =
                    _totalSupply.mul(newPool0.mul(amount1)) / (newPool0.add(newPool0).add(newReservoir0).mul(newPool1));

                uint256 value1AddedInTermsOf0 = (newPool0.mul(amount1)) / newPool1;
                require(newReservoir0 >= value1AddedInTermsOf0, "Buttonwood: INSUFFICIENT_RESERVOIR");

                // take from reservoir0 to make up for the missing value added
                newReservoir0 = newReservoir0.sub(value1AddedInTermsOf0);
                newPool0 = newPool0.add(value1AddedInTermsOf0);
            }
        }

        require(liquidity > 0, "Buttonwood: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _updateReservoirs(
            _pool0,
            _pool1,
            uint112(newPool0.add(amount0)),
            uint112(newPool1.add(amount1)),
            uint112(newReservoir0),
            uint112(newReservoir1)
        );
        if (feeOn) kLast = uint256(pool0).mul(pool1); // pool0 and pool1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _pool0, uint112 _pool1,) = getPools(); // gas savings
        (uint256 newReservoir0, uint256 newReservoir1) = getReservoirs(); // gas savings
        uint256 newPool0 = uint256(_pool0);
        uint256 newPool1 = uint256(_pool1);
        uint256 liquidity = balanceOf[address(this)];
        bool feeOn = _mintFee(_pool0, _pool1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        {
            // withdraw from both pools in proportion to the total value of each token held by this contract
            uint256 amountReservoir0 = liquidity.mul(newReservoir0) / _totalSupply;
            uint256 amountReservoir1 = liquidity.mul(newReservoir1) / _totalSupply;
            newReservoir0 = newReservoir0.sub(amountReservoir0);
            newReservoir1 = newReservoir1.sub(amountReservoir1);

            uint256 amountPool0 = liquidity.mul(newPool0) / _totalSupply;
            uint256 amountPool1 = liquidity.mul(newPool1) / _totalSupply;
            newPool0 = newPool0.sub(amountPool0);
            newPool1 = newPool1.sub(amountPool1);

            amount0 = amountPool0.add(amountReservoir0);
            amount1 = amountPool1.add(amountReservoir1);
        }

        require(amount0 > 0 && amount1 > 0, "Buttonwood: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        _updateReservoirs(_pool0, _pool1, newPool0, newPool1, newReservoir0, newReservoir1);
        if (feeOn) kLast = uint256(pool0).mul(pool1); // pool0 and pool1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burnFromReservoir(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _pool0, uint112 _pool1,) = getPools(); // gas savings
        (uint256 newReservoir0, uint256 newReservoir1) = getReservoirs(); // gas savings
        uint256 liquidity = balanceOf[address(this)];
        bool feeOn = _mintFee(_pool0, _pool1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        // calculate the amount to withdraw, purely from the reservoir
        // amount withdrawn is calculated as a proportion of the total value held by this contract,
        // for both tokens, but in terms of the token being withdrawn. Since by definition the value
        // of each pool is the same, 2 * (# of tokens in poolX) = the total value held in the pools, in terms of X
        if (newReservoir0 > 0) {
            amount0 = liquidity.mul(newReservoir0.add(_pool0).add(_pool0)) / _totalSupply;
        } else if (newReservoir1 > 0) {
            amount1 = liquidity.mul(newReservoir1.add(_pool1).add(_pool1)) / _totalSupply;
        }

        require(amount0 > 0 || amount1 > 0, "Buttonwood: INSUFFICIENT_LIQUIDITY_BURNED");
        require(amount0 == 0 || amount1 == 0, "Buttonwood: INVALID_RESERVOIR_BURN");
        require(newReservoir0 >= amount0 && newReservoir1 >= amount1, "Buttonwood: INSUFFICIENT_RESERVOIR");
        _burn(address(this), liquidity);
        if (amount0 > 0) {
            _safeTransfer(token0, to, amount0);
        } else if (amount1 > 0) {
            _safeTransfer(token1, to, amount1);
        }

        _updateReservoirs(_pool0, _pool1, _pool0, _pool1, newReservoir0.sub(amount0), newReservoir1.sub(amount1));
        if (feeOn) kLast = uint256(pool0).mul(pool1); // pool0 and pool1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "Buttonwood: INSUFFICIENT_OUTPUT_AMOUNT");

        (uint112 _pool0, uint112 _pool1,) = getPools(); // gas savings
        require(amount0Out < _pool0 && amount1Out < _pool1, "Buttonwood: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "Buttonwood: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IButtonwoodCallee(to).buttonwoodCall(msg.sender, amount0Out, amount1Out, data);
            (uint112 _reservoir0, uint112 _reservoir1) = getReservoirs(); // gas savings
            balance0 = IERC20(_token0).balanceOf(address(this)).sub(_reservoir0);
            balance1 = IERC20(_token1).balanceOf(address(this)).sub(_reservoir1);
        }
        uint256 amount0In = balance0 > _pool0 - amount0Out ? balance0 - (_pool0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _pool1 - amount1Out ? balance1 - (_pool1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "Buttonwood: INSUFFICIENT_INPUT_AMOUNT");
        {
            // scope for pool{0,1}Adjusted, avoids stack too deep errors
            uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(
                balance0Adjusted.mul(balance1Adjusted) >= uint256(_pool0).mul(_pool1).mul(1000 ** 2), "Buttonwood: K"
            );
        }

        _update(balance0, balance1, _pool0, _pool1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force reserves to match balances
    function sync() external lock {
        _syncReservoirs(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            pool0,
            pool1,
            reservoir0,
            reservoir1
        );
    }
}
