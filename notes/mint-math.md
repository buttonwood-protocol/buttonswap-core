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
That is to say, the ratio of the user's new $L$ tokens to the previous total supply $L_{total}$ must be equal to the value of the user's $A$ and $B$ deposits to the previous total value of $A$ and $B$ held by the pool:

```math
{L_{user} \over L_{total}} = {value(A_{user}) + value(B_{user}) \over value(A_{total}) + value(B_{total})}
```

### A note about $value$
It is important to understand that $A_{user}$ is an amount denominated in $A$ tokens and $B_{user}$ is an amount denominated in $B$ tokens.

For example, the following expression is valid because of consistent denomination:

```math
value(A_{total}) = value(A_{pool} + A_{reservoir}) = value(A_{pool}) + value(A_{reservoir})
```

Whilst this next expression is invalid because the token amounts are denominated in different tokens:

```math
value(A_{total}) + value(B_{total}) \neq value(A_{total} + B_{total})
```

Instead we must convert them into a common denomination in order to then do arithmetic with them.
The common denomination used can be arbitrary, but for simplicity we will henceforth treat $value$ as a function that converts an amount into one that is denominated in terms of $A$ tokens.

We will also define $p$ to be the price of $B$ tokens in terms of $A$ tokens, which is derived from the ratio of active liquidity balances:
```math
p = {A_{pool} \over B_{pool}}
```

Thus:

```math
value(A_{amount}) = A_{amount}
```
(Since $A_{amount}$ is already denominated in $A$, it is a 1:1 conversion)

And:

```math
value(B_{amount}) = B_{amount} \cdot p
```

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
For this example let us assume that $B$ reservoir is empty, and thus we deposit $B$ tokens to mint liquidity using $A$ tokens from the $A$ reservoir:

```math
B_{reservoir} = 0
```
```math
A_{user} = 0
```

Thus:

```math
L_{user} = L_{total} \cdot {value(A_{user}) + value(B_{user}) \over value(A_{pool}) + value(A_{reservoir}) + value(B_{pool}) + value(B_{reservoir})}
```
```math
L_{user} = L_{total} \cdot {value(B_{user}) \over value(A_{pool}) + value(A_{reservoir}) + value(B_{pool})}
```
```math
L_{user} = L_{total} \cdot {B_{user} \cdot p \over A_{pool} + A_{reservoir} + B_{pool} \cdot p}
```
```math
L_{user} = L_{total} \cdot {B_{user} \cdot {A_{pool} \over B_{pool}} \over A_{pool} + A_{reservoir} + B_{pool} \cdot {A_{pool} \over B_{pool}}}
```
```math
L_{user} = L_{total} \cdot {{B_{user} \cdot A_{pool} \over B_{pool}} \over A_{pool} + A_{reservoir} + A_{pool}}
```
```math
L_{user} = {L_{total} \cdot B_{user} \cdot A_{pool} \over B_{pool} \cdot (2 \cdot A_{pool} + A_{reservoir})}
```
