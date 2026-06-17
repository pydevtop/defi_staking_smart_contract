# ERC20 Staking Smart Contract (Solidity)

SecureStakeVault is a secure and configurable ERC20 staking smart contract designed for DeFi platforms, staking applications, token ecosystems, blockchain startups, DAOs, and Web3 projects.

Built with Solidity 0.8.x, the contract allows users to stake ERC20 tokens, earn rewards through configurable APY plans, harvest accumulated rewards, and perform emergency withdrawals with configurable penalties.

The architecture focuses on security, transparency, flexibility, and long-term maintainability while remaining compatible with Ethereum, BNB Chain, Polygon, Arbitrum, Base, Optimism, Avalanche, and other EVM-compatible blockchain networks.

## Features

* ERC20 Token Staking
* ERC20 Reward Distribution
* Multiple Staking Plans
* Configurable APY Rates
* Reward Reservation System
* Emergency Unstake Support
* Configurable Lock Periods
* Protected Reward Accounting
* Two-Step Ownership Transfer
* Reentrancy Protection
* Safe ERC20 Transfer Handling
* EVM Compatible Architecture

## Security Features

SecureStakeVault includes several mechanisms designed to improve user fund protection and operational safety.

* Reward obligations are reserved before accepting new stakes
* Reserved reward balances remain protected
* User staking funds are isolated from reward accounting
* Emergency unstake does not depend on external protocols
* Configurable penalty limits
* Protected administrative operations
* Safe ERC20 transfer wrappers
* Ownership transfer confirmation mechanism
* Reentrancy protection

## Supported Networks

* Ethereum
* BNB Chain
* Polygon
* Arbitrum
* Optimism
* Base
* Avalanche C-Chain
* Any EVM-Compatible Network

## Technologies

* Solidity 0.8.x
* ERC20 Standard
* DeFi Infrastructure
* EVM Architecture

## Use Cases

SecureStakeVault can be integrated into:

* DeFi Staking Platforms
* Yield Farming Applications
* Token Reward Programs
* DAO Incentive Systems
* Community Reward Platforms
* Launchpad Projects
* Blockchain Startups
* Web3 Applications
* Loyalty Programs
* Utility Token Ecosystems



## Constructor

```solidity
constructor(
    address payable _owner,
    address _stakeToken,
    address _rewardToken,
    uint256 _minimumStakeToken,
    uint256 _maxStakeableToken
)
```

### Parameters

| Parameter | Description |
|---|---|
| `_owner` | Initial contract owner |
| `_stakeToken` | ERC-20 token users deposit |
| `_rewardToken` | ERC-20 token used for rewards |
| `_minimumStakeToken` | Minimum allowed stake amount in raw token units |
| `_maxStakeableToken` | Maximum total active stake capacity in raw token units |

## Default Plans

The contract includes four default staking plans:

| Plan Index | Duration | APY |
|---:|---:|---:|
| `0` | 30 days | 10% |
| `1` | 90 days | 35% |
| `2` | 180 days | 70% |
| `3` | 365 days | 130% |

APY values use basis points:

```text
10,000 bps = 100%
1,000 bps  = 10%
```

## Main User Functions

### stake

```solidity
function stake(uint256 amount, uint256 timeperiod) external
```

Creates a new stake using one of the four plans.

Requirements:

- `timeperiod` must be from `0` to `3`
- `amount` must be at least `minimumStakeToken`
- total active stake must not exceed `maxStakeableToken`
- contract must have enough available reward tokens
- user must approve the contract to spend the staking token first

### harvest

```solidity
function harvest(uint256 index) public
```

Claims currently available rewards for a specific user stake.

### unstake

```solidity
function unstake(uint256 index) external
```

Claims remaining available rewards and returns the original staked amount after the lock period has ended.

### emergencyUnstake

```solidity
function emergencyUnstake(uint256 index) external
```

Exits early before lock expiration. Rewards are not paid during emergency unstake. A penalty is deducted from the staked amount and retained in the contract.

## Owner Functions

### setStakeLimits

Updates the minimum stake and maximum total active stake capacity.

### setStakeDuration

Updates the four staking durations. Durations must be ordered from shortest to longest and cannot exceed `MAX_DURATION`.

### setRewardApyBps

Updates APY values in basis points. APY values must be ordered from lowest to highest.

### setPenaltyBps

Updates emergency unstake penalty. Penalty is capped by `MAX_PENALTY_BPS`.

### withdrawUnrelatedToken

Allows withdrawal of unrelated ERC-20 tokens accidentally sent to the contract. It cannot withdraw the staking token or reward token.

### withdrawExcessRewardToken

Allows withdrawal of reward tokens only if they are not reserved for active stakes.

## Important Constants

```solidity
uint256 public constant PERCENT_DIVIDER = 10_000;
uint256 public constant YEAR = 365 days;
uint256 public constant MAX_DURATION = 365 days;
uint256 public constant MAX_PENALTY_BPS = 3_000; // 30%
```

## Deployment Example

Example for BNB Smart Chain using Remix:

1. Open Remix IDE.
2. Create `contracts/SecureStakeVault.sol`.
3. Paste the contract code.
4. Compile with Solidity `0.8.20` or compatible `0.8.x`.
5. Open **Deploy & Run Transactions**.
6. Select **Injected Provider - MetaMask**.
7. Select contract `SecureStakeVault`.
8. Fill constructor parameters.
9. Deploy.
10. Fund the contract with reward tokens before users start staking.

Example constructor values:

```text
_owner: 0xYourOwnerWallet
_stakeToken: 0xStakeTokenAddress
_rewardToken: 0xRewardTokenAddress
_minimumStakeToken: 1000000000000000000
_maxStakeableToken: 1000000000000000000000000
```

Raw token amounts depend on token decimals.

## Frontend Integration Notes

Before calling `stake`, the frontend should:

1. Read staking token decimals.
2. Convert user input with `parseUnits(amount, decimals)`.
3. Check wallet staking-token balance.
4. Check allowance.
5. Ask the user to approve if needed.
6. Call `stake(amount, planIndex)`.

The frontend should also read:

```solidity
getRewardBalance()
getUserStakeCount(address user)
stakersRecord(address user, uint256 index)
realtimeRewardPerBlock(address user, uint256 index)
```

## Disclaimer

This contract is provided as a reference implementation. It should be reviewed and tested before production use. Smart contracts can hold real funds, and deployment mistakes can be irreversible.


## Contacts
WhatsApp:  +380688011088<br>
Telegram:  @morgan_sql<br>
Telegram:  @systems_dev<br>


## License and Usage Notice

This project is licensed under the MIT License.

⚠️ However, unauthorized copying, redistribution, publication, or forking of this repository in a way that falsely attributes authorship or contributor status is strictly prohibited.

The author (PyDev) does not consent to being listed as a contributor in unauthorized forks or copies of this repository.

If you find any unauthorized fork or copy that misuses the author’s name, please report it to GitHub Support.

Author: PyDev

