# Position Smart Contract Documentation

## Overview

The `Position` contract represents a leveraged position in a lending pool. It allows users to open, manage, and close positions by supplying collateral, borrowing assets, and adjusting leverage. The contract integrates with a `LendingPool` to handle collateral and borrowing operations and supports flash loans for leverage adjustments. It also includes risk management features such as health checks and liquidation price calculations.

---

## Key Features

1. **Open Position**: Users can open a leveraged position by supplying collateral and borrowing assets.
2. **Add/Remove Collateral**: Users can add or withdraw collateral from their position.
3. **Adjust Leverage**: Users can increase or decrease the leverage of their position.
4. **Close Position**: Users can close their position, repay borrowed assets, and withdraw remaining collateral.
5. **Flash Loan Integration**: Supports flash loans for leverage adjustments.
6. **Risk Management**: Tracks liquidation price, health factor, and loan-to-value (LTV) ratio to ensure the position remains safe.

---

## Contract Details

### State Variables

| Variable Name                  | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `router`                       | Address of the router contract for swaps.                                   |
| `owner`                        | Address of the contract owner.                                              |
| `creator`                      | Address of the position creator.                                            |
| `lendingPool`                  | Reference to the associated `LendingPool` contract.                         |
| `baseCollateral`               | Initial collateral supplied by the user.                                    |
| `effectiveCollateral`          | Total collateral after including borrowed collateral.                       |
| `borrowShares`                 | Shares representing the borrowed assets.                                    |
| `leverage`                     | Current leverage of the position (default: 100).                           |
| `liquidationPrice`             | Price at which the position can be liquidated.                              |
| `health`                       | Health factor of the position.                                              |
| `ltv`                          | Loan-to-Value (LTV) ratio of the position.                                  |
| `lastUpdated`                  | Timestamp of the last position update.                                      |
| `flMode`                       | Flash loan mode (0 = none, 1 = add leverage, 2 = remove leverage, 3 = close). |

---

### Modifiers

None explicitly defined, but internal checks are used for validation.

---

### Functions

#### Constructor

```solidity
constructor(address _lendingPool, address _router, address _creator)
```

Initializes the contract with the lending pool, router, and creator address.

---

#### Add Collateral

```solidity
function addCollateral(uint256 amount) public
```

Allows users to add collateral to their position.

- **Parameters**:
  - `amount`: Amount of collateral to add.

---

#### Withdraw Collateral

```solidity
function withdrawCollateral(uint256 amount) public
```

Allows users to withdraw collateral from their position.

- **Parameters**:
  - `amount`: Amount of collateral to withdraw.

---

#### Borrow

```solidity
function borrow(uint256 amount) external
```

Allows users to borrow assets against their collateral.

- **Parameters**:
  - `amount`: Amount of assets to borrow.

---

#### Open Position

```solidity
function openPosition(uint256 amount, uint256 debt) public
```

Opens a leveraged position by supplying collateral and borrowing assets.

- **Parameters**:
  - `amount`: Amount of collateral to supply.
  - `debt`: Amount of assets to borrow.

---

#### On Flash Loan

```solidity
function onFlashLoan(address token, uint256 amount, bytes calldata) external
```

Callback function for flash loans. Used to adjust leverage.

- **Parameters**:
  - `token`: Address of the token borrowed in the flash loan.
  - `amount`: Amount of tokens borrowed.
  - `data`: Additional data (unused).

---

#### Update Leverage

```solidity
function updateLeverage(uint256 newLeverage) external
```

Adjusts the leverage of the position.

- **Parameters**:
  - `newLeverage`: New leverage value (must be between 100 and 500).

---

#### Close Position

```solidity
function closePosition() external returns (uint256)
```

Closes the position, repays borrowed assets, and withdraws remaining collateral.

- **Returns**: The remaining amount of assets after repayment.

---

### Internal Functions

#### `_emitUpdatePosition()`

Emits an event with the current position details.

#### `_emitSupplyCollateral()`

Emits an event when collateral is supplied.

#### `_emitWithdrawCollateral()`

Emits an event when collateral is withdrawn.

#### `_emitBorrow()`

Emits an event when assets are borrowed.

#### `_emitRepay()`

Emits an event when assets are repaid.

#### `_supplyCollateral(uint256 amount)`

Internal function to supply collateral to the lending pool.

#### `_borrow(uint256 amount)`

Internal function to borrow assets from the lending pool.

#### `_flAddLeverage(address token, uint256 amount)`

Internal function to add leverage using a flash loan.

#### `_swap(address loanToken, address collateralToken, uint256 amount)`

Internal function to swap tokens using the router.

#### `_checkHealth()`

Internal function to check the health of the position and revert if it is at risk.

---

### Events

| Event Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `UserPosition`                 | Emitted when the position is updated.                                       |
| `SupplyCollateral`             | Emitted when collateral is supplied.                                        |
| `WithdrawCollateral`           | Emitted when collateral is withdrawn.                                       |
| `Borrow`                       | Emitted when assets are borrowed.                                           |
| `Repay`                        | Emitted when assets are repaid.                                             |

---

### Errors

| Error Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `InvalidToken`                 | Thrown when an invalid token is used in a flash loan.                       |
| `InsufficientCollateral`       | Thrown when there is insufficient collateral to withdraw.                   |
| `InsufficientMinimumLeverage`  | Thrown when the leverage is below the minimum (100).                        |
| `LeverageTooHigh`              | Thrown when the leverage exceeds the maximum (500).                         |
| `NoChangeDetected`             | Thrown when the leverage update does not change the current value.          |
| `PositionAtRisk`               | Thrown when the position is at risk of liquidation.                         |
| `ZeroAddress`                  | Thrown when a zero address is provided.                                     |
| `ZeroAmount`                   | Thrown when a zero amount is provided.                                      |

---

## Conclusion

The `Position` contract is a powerful tool for managing leveraged positions in a decentralized lending pool. It integrates with flash loans for leverage adjustments, provides risk management features, and emits events for tracking position changes. This contract is essential for users who want to engage in leveraged trading while maintaining control over their risk exposure.