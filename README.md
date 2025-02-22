# Crypto Leverage Platform

This repository contains smart contracts for a decentralized crypto leverage platform, including the **LendingPool**, **LendingPoolFactory**, **Position**, and **PositionFactory** contracts. The platform provides functionalities for borrowing, earning, leveraging positions, and managing lending pools.

---

## Smart Contracts

### 1. **LendingPool**
The `LendingPool` smart contract manages lending and borrowing operations, setting interest rates, managing collateral, and handling liquidations within the lending pool.

#### Key Features
- **Supply Collateral**: `supplyCollateralByPosition()` allows users to supply collateral to their positions.
- **Borrow Assets**: `borrowByPosition()` lets users borrow assets against their collateral.
- **Repay Borrowed Assets**: Repay borrowed assets and manage debt positions.
- **Liquidation**: Automatically liquidate under-collateralized positions.
- **Get Pool Status**: Provides health, LTV, and liquidation price information.

---

### 2. **LendingPoolFactory**
The `LendingPoolFactory` contract enables the creation, storage, management, and deletion of `LendingPool` instances within the leverage platform.

#### Key Features
- **Create LendingPool**: Initialize a new lending pool with parameters such as loan token, collateral token, price feeds, liquidation threshold, interest rate, and position type.
- **Manage Pool Status**: Activate, deactivate, and discard lending pools.
- **Store External Pools**: Allows integration of external lending pools into the factory's index.
- **Indexing**: Automates the indexing of all active pools.

---

### 3. **Position**
The `Position` contract manages leveraged positions, allowing users to add collateral, withdraw collateral, borrow against it, and handle flash loans to increase leverage.

#### Key Features
- **Add/Withdraw Collateral**: Safely manage collateral within a position.
- **Open Position**: Initialize a leveraged position using a flash loan.
- **Flash Loan Integration**: Supports Uniswap for swapping assets during leverage operations.
- **Health Checks**: Validates the safety of positions to avoid liquidation.

---

### 4. **PositionFactory**
The `PositionFactory` contract facilitates the creation of new positions within a specified lending pool, initializing positions with base collateral and leverage.

#### Key Features
- **Create New Position**: Deploys a new `Position` contract and initializes it.
- **Position Management**: Manages active positions through mapping and event logging.

---

## How to Use

### Deployment Steps
1. Deploy the `LendingPoolFactory` contract.
2. Create a `LendingPool` using `createLendingPool()`.
3. Deploy the `PositionFactory` contract.
4. Create a `Position` with `createPosition()` and initialize it with base collateral and leverage.

### Managing Lending Pools
- **Activate/Deactivate Pools**: Use `updateLendingPoolStatus()` in `LendingPoolFactory`.
- **Discard Pools**: Call `discardLendingPool()` to safely remove pools.

### Managing Positions
- **Add/Withdraw Collateral**: Use the `Position` contract's functions to adjust collateral.
- **Leverage Positions**: Integrate with the Uniswap router for flash loans and asset swaps.

---

## Events
The platform uses **EventLib** to log key activities:
- `CreateLendingPool`, `StoreLendingPool`, `DiscardLendingPool` for pools.
- `UserPosition`, `SupplyCollateral`, `WithdrawCollateral` for positions.
- `PositionCreated` for position factory actions.

---

## Testing & Validation
Test scenarios should cover:
- **LendingPool**: Creation, collateral management, borrowing, liquidation.
- **LendingPoolFactory**: Pool creation, activation, deletion, and indexing.
- **Position**: Collateral management, leverage operations, and flash loan handling.
- **PositionFactory**: Position creation and initialization.

---

## Dependencies
- **OpenZeppelin**: `IERC20` and `ERC20` for token standards.
- **Chainlink**: `AggregatorV2V3Interface` for price feeds.
- **Uniswap V3**: `ISwapRouter` for asset swapping during leverage.

---

For further questions or support, please contact the development team.

