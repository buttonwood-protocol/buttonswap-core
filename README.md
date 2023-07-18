# buttonswap-core

Buttonswap is an AMM protocol that protects pairs with rebasing tokens from price-impact due to rebasing balances.
Buttonswap achieves this by using a constant product invariant for swaps while maintaining reservoirs for the remaining inactive liquidty that accrues.

It is important to note that while Buttonswap pairs are immune to changes in marginal price from responding to rebases, a contraction in active liquidity will result increased price-impact from swaps.

Buttonswap also supports single-sided operations for shifting the liquidity from inactive back to active. This process resembles an exchange of the reservoir assets, but does not have the swap fee imposed. This is to incentivize the process, and there are safeguards for the reservoir which also serve to inhibit the use of it to bypass swap fees entirely.

## Notes
Refer to the documents in [/notes](/notes) for detailed explanations of the mechanics.

## Testing

The unit tests contained within `/test/known-issues/` are excluded from being run during pull request, but included during merge to main.

If the underlying issue for the test has been fixed, the test should be migrated back to the contract's test file.
