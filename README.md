# buttonswap-core

Buttonswap is an AMM protocol that protects pairs with rebasing tokens from price-impact due to rebasing balances.
Buttonswap achieves this by using a constant product invariant for swaps while maintaining reservoirs for the remaining inactive liquidty that accrues.

It is important to note that while Buttonswap pairs are immune to changes in marginal price from responding to rebases, a contraction in active liquidity will result in increased price-impact from swaps.

Buttonswap also supports single-sided operations for shifting the liquidity from inactive back to active. This process resembles an exchange of the reservoir assets, but does not have the swap fee imposed. This is to incentivize the process, and there are safeguards for the reservoir which also serve to inhibit the use of it to bypass swap fees entirely.

## Notes
Refer to the documents in [/notes](/notes) for detailed explanations of the mechanics.

## Audit
Refer to [statemind_2023-08-11.pdf](/notes/statemind_2023-08-11.pdf) for the official audit report conducted by State Mind.

## Testing

The unit tests contained within `/test/known-issues/` are excluded from being run during pull request, but included during merge to main.

If the underlying issue for the test has been fixed, the test should be migrated back to the contract's test file.

## Deploying

First edit the `Deploy.s.sol` script to configure the constructor arguments as required. Then use the script as follows:
```
forge script script/Deploy.s.sol --broadcast --rpc-url sepolia --verify --watch
```

This will attempt to verify the contract at the same time, but if you get `Error: contract does not exist` error then verification can be done as follows:

First compute the constructor args in ABI encoded format:
```
cast abi-encode "constructor(address _feeToSetter, address _isCreationRestrictedSetter, address _isPausedSetter, address _paramSetter, string memory _tokenName, string memory _tokenSymbol)" 0xb1Cc73B1610863D51B5b8269b9162237e87679c3 0xb1Cc73B1610863D51B5b8269b9162237e87679c3 0xb1Cc73B1610863D51B5b8269b9162237e87679c3 0xb1Cc73B1610863D51B5b8269b9162237e87679c3 "Buttonswap LP Token V1" "BSWP-V1"
```

Then substitute the appropriate values in the following:
```
forge verify-contract <deployed contract address> src/ButtonswapFactory.sol:ButtonswapFactory --chain sepolia --constructor-args <output from cast command> --watch
```
