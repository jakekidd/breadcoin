# BreadCoin

After extensive research and questionable decision-making, BreadCoin v1.0 is a bread-based currency. It cannot be exchanged for real bread, but maybe
in the future it can, somewhere, somehow. We'll see. But it will cost extra, with inflation.

## Key Features

- ERC-20 compliant (0 decimals - whole loaves only)
- Initial supply: 123,000 BREAD (blessed number)
- Max supply: 1,000,000 BREAD (sanity cap, we don't have unlimited bread)
- Dynamic pricing: starts at 0 wei, +1 wei per block #inflation

## Core Mechanics

The BreadCoin contract is designed to be straightforward but engaging, with features that control supply, pricing, and user interaction.

### Pricing Model

The price of BreadCoin is designed to increase over time in a predictable manner.

- **Linear Inflation**: The price for one BreadCoin starts at 1 wei and increases by 1 wei with every new block mined after the contract's deployment. The price can be checked at any time using the `price()` view function.
- **Bulk Discount**: A 10% discount is automatically applied to the total cost when purchasing 100 or more loaves in a single transaction.
- **Cost Calculation**: The `quote(numLoaves)` function allows users to get an exact cost for a specific number of loaves, including any applicable bulk discounts.

### Acquiring BreadCoin (Baking)

Users can acquire BreadCoin by "baking" it, which is the contract's term for minting.

- **`bake(numLoaves)`**: This function allows a user to mint an exact number of tokens. The user must send enough ETH to cover the cost, which is calculated based on the current price and quantity. Any excess ETH sent is automatically refunded.
- **`bakeMax()`**: For convenience, a user can call this function and send an arbitrary amount of ETH. The contract will calculate the maximum number of loaves they can afford, mint them, and refund any remaining dust. I don't recommend you do this.

### Key Functions

- **`toast(amount)`**: A deflationary mechanism that allows users to permanently burn their BreadCoin tokens, reducing the total supply.
- **`knead()`**: A non-financial function that allows users to interact with the contract. It tracks the number of times a user has kneaded, storing the count in the `_crumbs` mapping. This is for \[TBD NFT\]
- **`makeDough()`**: This is so I can actually make money. I mean bread

### Contract Details

- **Token Standard**: ERC20
- **Decimals**: 0 (Tokens are not divisible)
- **Max Supply**: 1,000,000 BREAD
- **Security**: The contract inherits from OpenZeppelin's `Ownable` and `ReentrancyGuard` contracts to ensure secure ownership and prevent common vulnerabilities.

## Development and Testing

1.  Install Foundry: `curl -L https://foundry.paradigm.xyz | bash` and then run `foundryup`.
2.  Install dependencies: `forge install`.

### Testing

Run the full test suite with `forge test`. The tests cover all core functions, pricing logic, access control, and edge cases.
