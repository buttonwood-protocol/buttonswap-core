# Redesign

## Problems with current core contract:

- assumes that sync will be called before every other operation, but does not enforce this
  - allows for theft of tokens added during rebase via a mint, possibly other attacks too
  - can be mitigated by prohibiting calls that don't come via router, where sync is called when it should be
  - can't have the core contract itself call sync at the start of every operation as that breaks the pattern used to detect how many tokens the user has sent the contract
- believe swap fee is applied to rebased funds during sync
  - this has the effect of the feeTo address stealing from other LPers
  - can probably be addressed by tweaking some things, haven't looked closely
- during sync the pool does not compute the optimal new active liquidity virtual balances
  - by optimal I mean ones that produce a price ratio that most closely matches the previous one
  - can be addressed by adjusting the sync code
    - sync code in general seems to be far more complex than is necessary
- naive implementations of rebasing tokens break the contract
  - eg. user balance is product of underlying balance and multiplier
  - this is prone to balance changes being rounded to multiples of multiplier
  - this breaks the contract's checks for operations handling proper ratios of A and B

## Other desired changes to core contract:

- remove SafeMath library in favour of the solidity native approach
- add NatSpec

## Redesign ideas

### Interface overhaul

This is primarily aimed at addressing the sync issue.
By changing the interface we can return to the core contact being safely standalone, without requiring all interactions go via the router.
This is done by syncing at the start, but handling token transfers internally so avoid the code confusing transfers and rebases.

#### Current interface:
```solidity
contract ButtonswapPair {
    uint pool0;
    uint pool1;
    uint reservoir0;
    uint reservoir1;
    
    function mint(address to) external returns (uint256 liquidity){
        uint amount0 = token0.balanceOf(this) - pool0 - reservoir0;
        // same for amount1
        // calculate liquidity based on amount0 and amount1 being deposited
    }

    function mintWithReservoir(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amountA, uint256 amountB);

    function burnFromReservoir(address to) external returns (uint256 amountA, uint256 amountB);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}
```

All the operations behave in a similar way to the `mint` pseudocode, deducing the amounts a user has sent to the contract from the delta of actual and virtual balances.
If the pool is synced right before the operation this works fine, but if not then surplus tokens from rebase are confused with tokens sent in by user.

#### Proposed interface:
```solidity
contract ButtonswapPair {
    uint pool0;
    uint pool1;
    uint reservoir0;
    uint reservoir1;
    
    function mint(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity){
        sync();
        token0.transferFrom(msg.sender, this, amount0);
        uint actualAmount0 = token0.balanceOf(this) - pool0 - reservoir0;
        // same for amount1
        // calculate liquidity based on actualAmount0 and actualAmount1 being deposited
    }

    function mintWithReservoir(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity);

    function burn(uint256 amount, address to) external returns (uint256 amountA, uint256 amountB);

    function burnFromReservoir(uint256 amount, address to) external returns (uint256 amountA, uint256 amountB);

    function swap(uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}
```

Here the operations first sync to make sure any surplus tokens from rebase are handled appropriately.
Then it handles the transfer of tokens the user is sending the contract.
Because of fee-on-transfer tokens and other wildcards, we can't assume that the amount we try to send is the amount the contract balance increases by.
Hence we then calculate the `actualAmount0` as the delta of balance and virtual balances again.

Caveats:

- The router needs to approve the core contract to move tokens on its behalf
- Interface diverges from software build to match UniswapV2
  - this should be able to be mitigated by making a contract that maps it back to original interface

### Ephemeral Sync

Currently, virtual balances for both the active liquidity (poolX) and inactive liquidity (reservoirX) are tracked as storage values.

I believe this is excessive, and the same outcome can be achieved by only tracking the last used price ratio (as two storage values, numerator and denominator).

At the start of every operation we can call a modified sync method that simply returns the active and inactive liquidity values in memory, based on maximising the active liquidity with current token balances and last known price ratio.
There is thus no need to store these values after we're done, provided an updated price ratio is stored.

In practise the price ratio is likely just the active liquidity values, with this saving us from storing the reservoir values.

It might also be worth exposing getters for the original pool and reservoir values that give an always up to date freshly calculated value using this ephemeral sync.
This would be similar to how button tokens rebase continuously, giving fresh balance values even without write interactions to persist them. 

### Laxer restrictions on operations, and merging dual and single sided operations

This is born in part from addressing the issue of supporting naive rebasing tokens.

The essence of it is the following:
> Why reject mints with amounts that don't match price ratio when we can instead stuff the surplus in the reservoir?

The liquidity tokens a user receives must be derived from the ratio of the value they're adding and the value that was already there.

But we don't actually need the value added to match the price ratio.

Worked example:
```
t0:
pool0 = 4
pool1 = 6
reservoir0 = 2
reservoir1 = 0
valueInTermsOf0 = 4 + (6*4/6) + 2 + 0 = 10
LPtokenSupply = 10
total0 = pool0 + reservoir0 = 6
total1 = pool1 + reservoir1 = 6

user mints, sending in the following:
amount0 = 4
amount1 = 3
valueDepositedInTermsOf0 = 4 + (4*3/6) = 6 

user receives LP tokens in ratio of value deposited : value there
LPtokenUser = 6

total0 = pool0 + reservoir0 + amount0 = 10
total1 = pool1 + reservoir1 + amount1 = 9

we now do a new sync to update our active and inactive liquidity values, maintaing the previous price ratio

t1:
pool0 = 6
pool1 = 9
reservoir0 = 4
reservoir1 = 0

we can see that 6:9 matches the original 4:6
reservoir0 has grown by 2

if the user were to burn their 6 LP tokens, they receive:
redeemed0 = (6+4) * 6/16 = 3.75
redeemed1 = (9+0) * 6/16 = 3.375

do a new sync

t2:
pool0 = 3.75
pool1 = 5.625
reservoir0 = 2.5
reservoir1 = 0

we can see that 3.75:5.625 still matches original 4:6
compared to t0, we maintain same price, same value, but more liquidity has shifted to reservoir
```

I've outlined the mint scenario, but I believe this could be similarly applied to swap and burn too.
For swap you send arbitrary amounts in and get back values that preserve K and maximise active liquidity.

Caveats:

- As described above it permits users to deliberately grow inactive liquidity in unconstrained fashion, reducing depth for trades
- Can enable further use of single-sided operations to bypass swap fees
- This approach is intended to unify dual and single sided operations, but it's possible that there can be gas efficiency in maintaining separate methods (?)

### Protocol Fee

Current design is to mint LP tokens to the `feeTo` address, granting ownership over a greater amount of the token0 and token1 held in the pool in the process.

The intention is only collect a fee as a fraction of the liquidity growth (increase in K) when a swap takes LP fees.

eg.
- user swaps A for B
- value(B_out) = 0.997 * value(A_in)
  - (0.3% of value is retained as LP fees)
- LP representing (1/6) * 0.997 * value(A_in) is minted to feeTo
  - 1/6th of the LP fees is given to the feeTo address

The current implementation of this suffers from not excluding growth in K during a sync after a positive rebase shifts liquidity from reservoir to pool.
I expect it possible to adjust behaviour to prevent this whilst retaining the same general approach.

However, I also wonder if it would make more sense to instead send protocol fee directly as a fraction of the output token.
That is, rather than give LP representing a mix of A and B when A is swapped for B, give it a fraction of B itself.

This has the benefit where the protocol retains overall more value from fees long term.

Imagine an ETH/SHITCOIN pair.
At first they might trade as if SHITCOIN has value, but eventually it'll go to 0.
In the process the ETH will be emptied from the pool, leaving the protocol with a claim on vast amounts of worthless SHITCOIN instead.
In effect - any fees the protocol earned on that pool are worthless.

By collecting fees as the raw tokens themselves, the protocol will be left with a mix of valuable ETH and worthless SHITCOIN at the end of the pool's lifetime instead.

It should also simplify the fee mechanism significantly.

Caveats:
- Generally the highest earning pools are the ones that have two valuable tokens, making it debatable whether the protocol earns significantly more by collecting in raw tokens
- Reduces the liquidity depth since the collected fees are not staked as liquidity
  - if your fees are worth something, this impact is not minimal
  - if this impact is minimal, then your fees are not worth something which partially refutes the point of this change
- The extra token transfer might be more gas costly than the internal balance update of an LP mint (?)

