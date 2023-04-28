# Mint Math

The pool has two tokens that it serves as a market for, $A$ and $B$.

To handle rebasing assets, the pool keeps track of active liquidity and surplus liquidity with virtual balances.
Thus, the active $A$ liquidity $A_{pool}$ and surplus $A$ liquidity $A_{reservoir}$ sum to the total balance held by the contract $A_{total}$:

```math
A_{total} = A_{pool} + A_{reservoir}
```
(The same holds true for $B$ as well)

The pool also issues its own token to track user ownership of its liquidity, $L$.

This works via proportional redemption.
If a user's balance is $L_{user}$ and the total supply of the liquidity token is $L_{total}$ then the user has a claim to $A_{user}$ tokens:

```math
A_{user} = A_{total} \cdot {L_{user} \over L_{total}}
```
## Minting

When a user deposits liquidity and receives $L$ tokens we must calculate the amount they receive such that it preserves their claim to $A$ and $B$.

### Dual-sided Mint

A dual-sided mint refers to when the user deposits both $A$ and $B$ in a ratio that matches the current total token balances:

```math
{A_{user} \over B_{user}} = {A_{total} \over B_{total}}
```

Which we can rearranged as follows:

```math
{A_{user} \over A_{total}} = {B_{user} \over B_{total}}
```

Liquidity tokens are minted to match this ratio.
This is a very simple way to ensure that existing $L$ holders can redeem their $L$ tokens after a new user mints for at least as many $A$ and $B$ tokens as they could before:

```math
{L_{user} \over L_{total}} = {A_{user} \over A_{total}} = {B_{user} \over B_{total}}
```
```math
L_{user} = L_{total} \cdot {A_{user} \over A_{total}} = L_{total} \cdot {B_{user} \over B_{total}}
```

When this is done, any existing reservoir balances will grow too.
As shown, we actually have two ways of calculating $L_{user}$ by using either values in terms of $A$ or values in terms of $B$.
This assumes that $A$ and $B$ are deposited in a ratio that matches the existing balances, but in reality integer rounding makes this imperfect.
The code implementation also skips enforcing that the deposited tokens are in the correct ratio to save on gas as well.
Instead, we calculate $L_{user}$ both ways and then use the smallest of the two values:

```math
L_{user} = \min\{L_{total} \cdot {A_{user} \over A_{total}}, L_{total} \cdot {B_{user} \over B_{total}}\}
```

With this, any tokens that exceed the ${A_{total} \over B_{total}}$ ratio are effectively donated, benefiting pre-existing $L$ holders.

### Single-sided Mint

A single-sided mint refers to when the user deposits only one of $A$ or $B$, with the pool reservoir supplying the required counterpart in a ratio that matches the current price.
For this example let us assume that $A$ reservoir is empty, and thus we deposit $A$ tokens to mint liquidity using $B$ tokens from the $B$ reservoir.
The amount $A_{user}$ that a user deposits consists of $A_{x}$, the amount of $A$ to be used for minting dual sided liquidity, and $A_{y}$, the amount of $A$ to be exchanged for reservoir $B$ tokens that pair with $A_{x}$ for the dual sided mint:
```math
A_{user} = A_{x} + A_{y}
```
Let $p_{ma}$ be the moving average price of $A$ in terms of $B$.
$B_{y}$ is the $B$ tokens swapped out of the reservoir in exchange for $A_{y}$, with the swap being priced at the moving average price:
```math
B_{y} = A_{y} \cdot p_{ma}
```
The ratio of tokens for a new dual sided mint should match the price ratio of the pair:
```math
{A_{x} \over B_{y}} = {A_{pool} \over B_{pool}}
```

Now with some substitution:
```math
{A_{user} - A_{y} \over A_{y} \cdot p_{ma}} = {A_{pool} \over B_{pool}}
```
```math
A_{user} - A_{y}  = A_{y} \cdot p_{ma} \cdot {A_{pool} \over B_{pool}}
```
```math
A_{user} = A_{y} \cdot (1 + p_{ma} \cdot {A_{pool} \over B_{pool}})
```
```math
{A_{user} \over (1 + p_{ma} \cdot {A_{pool} \over B_{pool}})} = A_{y}
```

Further rearrangement to minimise premature rounding:
```math
A_{y} = {A_{user} \over ({B_{pool} \over B_{pool}} + p_{ma} \cdot {A_{pool} \over B_{pool}})}
```
```math
A_{y} = {A_{user} \over {B_{pool} + p_{ma} \cdot A_{pool} \over B_{pool}}}
```
```math
A_{y} = {A_{user} \cdot B_{pool} \over B_{pool} + p_{ma} \cdot A_{pool}}
```

From here we do a dual sided mint using the new values we computed:

```math
L_{user} = \min\{L_{total} \cdot {A_{x} \over A_{total}}, L_{total} \cdot {B_{y} \over B_{total}}\}
```

### Validation

A key objective for the single sided operation is to ensure that reservoirs shrink or stay the same when executing the operation.
This imposes a limit on how much can be minted in this fashion.
From the user's perspective, we exchanged $A_{y}$ for $B_{y}$ and then calculated what amounts are required to do this and the subsequent dual mint optimally.
From the perspective of the Pair, however, we have now gained $A_{y}$.
In order to avoid growing $A_{reservoir}$ from zero we need $B_{reservoir}$ to supply enough $B$ to match $A_{y}$ at the current Pair price.
Thus:
```math
A_{y} \cdot {B_{pool} \over A_{pool}} \leq B_{reservoir} - B_{y}
```
