# No-Loss Lottery Protocol

## Overview

This project implements a **no-loss lottery protocol** in Solidity.

Users deposit ERC20 tokens into a pool during a deposit window.
After deposits close, the pooled funds are invested into an external yield source via an adapter.

At the end of the round:

* all users withdraw their original deposits,
* one winner receives the generated yield.

The probability of winning is proportional to the user’s share of total deposits.

---

## Key Idea

Unlike traditional lotteries:

* users **do not lose their principal**
* only the **yield is distributed as a prize**

This makes the system capital-efficient and low-risk.

---

## Contracts

### `TestToken.sol`

ERC20 token used for testing and Sepolia demo.

### `MockYieldVault.sol`

Mock yield source used for testing. Simulates profit generation.

### `YieldAdapter.sol`

Adapter that connects the lottery contract to the vault.

### `NoLossLottery.sol`

Core contract that manages:

* rounds
* deposits
* investment
* winner selection
* withdrawals

---

## Architecture

User
↓
NoLossLottery
↓
YieldAdapter
↓
MockYieldVault

The adapter pattern allows replacing the yield source without changing the lottery logic.

---

## Round Lifecycle

1. Admin creates a round
2. Users deposit tokens
3. Deposit window closes
4. Admin calls `investRound`
5. Funds are transferred to the vault
6. Yield is generated
7. Admin calls `finalizeRound`
8. Winner is selected
9. Users withdraw funds

---

## Math

Let:

* `d_i` — deposit of user `i`
* `D = sum(d_i)` — total deposits
* `A_final` — funds returned from vault
* `Y = A_final - D` — yield

### Winner probability

`P_i = d_i / D`

### Withdrawals

* Regular user:
  `W_i = d_i`

* Winner:
  `W_winner = d_winner + Y`

---

## Security Features

* `Ownable'
* `SafeERC20`
* Round state validation
* Double-withdraw protection

---

## Tests

Run tests:

```bash
forge test -vv
```

### Result

✅ **All tests passed**

### Coverage

The test suite verifies:

* round creation
* deposits from multiple users
* multiple deposits by one user
* deposit deadline enforcement
* invest phase execution
* yield accounting
* round finalization
* correct winner selection
* correct payout distribution
* no-loss guarantee
* double-withdraw prevention

The protocol behaves correctly under all tested scenarios.

---

## Deployment (Sepolia)

### Deployer

```
0x3c82137c7Fce586482d10B9a8eb331Fc04966459
```

### Contracts

* TestToken: `0xcBAbf7AdA534bC8BF90eCA364135f38abFa1BcCF`
* MockYieldVault: `0x8b446bDb64cD96b26A6C381048a3F7B78d145FCd`
* YieldAdapter: `0xd339A8A7dF4AD2f8f4F5AAFb1404C6898E30a45c`
* NoLossLottery: `0xd82d76204b7407090e989af2217207a4a5Ef9b2f`

---

## Live Demo (Sepolia)

### Participants

* User1: `0x5F1cF930Cc21583EeF5226AdBfC82F6d30af76eD`
* User2: `0xb721C8d66a8de7329039dD0eb31D055a14AEf6e9`

---

### Round #1

#### Deposits

* User1: 100 tokens
* User2: 200 tokens

Total pool: 300 tokens

---

#### Investment

Admin called:

```bash
investRound(1)
```

Funds were transferred into the vault via the adapter.

---

#### Yield Generation

```bash
addYield = 50 tokens
```

---

#### Finalization

```bash
finalizeRound(1)
```

Winner selected:

```
User2 (0xb721...)
```

---

#### Withdrawals

User1:

```
withdraw → 100 tokens
```

User2:

```
withdraw → 250 tokens
```

---

## Final Outcome

| User  | Deposit | Reward | Total |
| ----- | ------- | ------ | ----- |
| User1 | 100     | 0      | 100   |
| User2 | 200     | 50     | 250   |

---

## Conclusion

The demo confirms:

* no-loss guarantee holds
* yield is correctly distributed
* winner selection works
* full round lifecycle executes on-chain

---

## How to Run

### Build

```bash
forge build
```

### Test

```bash
forge test -vv
```

### Deploy

```bash
source .env

forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

### Setup Demo

```bash
source .env

forge script script/SetupDemo.s.sol:SetupDemoScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

---

## Future Improvements

* Chainlink VRF for randomness
* Automation (keepers) for round execution
* Integration with real yield protocols (Aave, Compound)
* Frontend (React + wagmi)

---

## Summary

This project demonstrates a complete **DeFi no-loss lottery protocol**, including:

* smart contract system
* testing suite
* deployment scripts
* real testnet execution
* verified economic model
