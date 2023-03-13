# Swap Math

The pool has two tokens, $A$ and $B$.

The pool's token balances changes during a swap.

Let $A_S$ and $B_S$ represent the start balances for how many tokens the pool has.
Let $A_E$ and $B_E$ represent the end balances for how many tokens the pool has.

## K invariant

$K$ refers to the product of the pool token balances.

The rule by which this AMM operates is that $K$ does not change during a swap.

Thus:
```math
K = A_S \cdot B_S
```
```math
K = A_E \cdot B_E
```
```math
A_S \cdot B_S = A_E \cdot B_E
```

## Swap Calculations

Let us trade $x$ amount of $A$ for $B$.

We expect back amount $y$ of token $B$. 

Thus:

```math
A_E = A_S + x
```
```math
B_E = B_S - y
```

Substituting with our equations from before, we have:
```math
A_S \cdot B_S = (A_S + x) \cdot (B_S - y)
```

We wish to determine $y$, so:
```math
A_S \cdot B_S = (A_S + x) \cdot (B_S - y)
```
```math
{A_S \cdot B_S \over A_S + x} = B_S - y
```
```math
y = B_S - {A_S \cdot B_S \over A_S + x}
```
```math
y = {B_S \cdot (A_S + x) \over A_S + x} - {A_S \cdot B_S \over A_S + x}
```
```math
y = {B_S \cdot (A_S + x) - A_S \cdot B_S \over A_S + x}
```
```math
y = {B_S \cdot A_S + B_S \cdot x - A_S \cdot B_S \over A_S + x}
```
```math
y = { B_S \cdot x \over A_S + x}
```

This works both ways, so more generally, if rather than $A$ and $B$ we have $I$ and $O$ to represent the Input token and the Output token, we have:

```math
y = { O_S \cdot x \over I_S + x}
```

## Fee mechanism

The expression above describes the expected output amount for a swap with no fee.

In practise, the pool actually operates with a 0.3% fee, which is deducted from the output amount the swapper receives.

This is done by calculating the output amount received if the input amount were to have the fee deducted.

Let $f$ be the fee of 0.3%.
The contracts rely on integer math, so we represent $f$ as a fraction $f = {f_n \over f_d}$ where $f_n = 3$ and $f_d = 1000$.

Let $F$ be the input amount scalar, where $F = 1 - f$. Thus we have $F = {F_n \over F_d}$ where $F_n = f_d - f_n$ and $F_d = f_d$.

Apply this to the output amount expression from above and we have:

```math
y = {O_S \cdot (x \cdot F) \over I_S + (x \cdot F)}
```
```math
y = {O_S \cdot x \cdot {F_n \over F_d} \over I_S + (x \cdot {F_n \over F_d})}
```
```math
y = {{O_S \cdot x \cdot F_n \over F_d} \over {I_s \cdot F_d \over F_d} + {x \cdot F_n \over F_d}}
```
```math
y = {O_S \cdot x \cdot F_n \over (I_S \cdot F_d) + (x \cdot F_n)}
```

With values for a 0.3% fee substituted:
```math
y = {O_S \cdot x \cdot 997 \over (I_S \cdot 1000) + (x \cdot 997)}
```
