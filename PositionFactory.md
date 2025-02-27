# PositionFactory Smart Contract Documentation

## Overview

The `PositionFactory` contract is responsible for creating and managing `Position` contracts. It allows users to open and close leveraged positions by interacting with a `LendingPool`. The factory handles collateral transfers, position registration, and emits events for tracking position creation and deletion.

---

## Key Features

1. **Create Position**: Deploys a new `Position` contract and opens a leveraged position.
2. **Delete Position**: Closes an existing position and transfers remaining assets to the user.
3. **Collateral Management**: Handles collateral transfers and approvals.
4. **Position Tracking**: Tracks positions created by users.
5. **Event Emission**: Emits events for position creation and deletion.

---

## Contract Details

### State Variables

| Variable Name                  | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `positions`                    | Mapping of user addresses to their created positions.                       |

---

### Functions

#### Create Position

```solidity
function createPosition(address _lendingPool, uint256 _baseCollateral, uint256 _leverage)
    external
    returns (address)
```

Creates a new `Position` contract and opens a leveraged position.

- **Parameters**:
  - `_lendingPool`: Address of the lending pool.
  - `_baseCollateral`: Amount of collateral to supply.
  - `_leverage`: Leverage multiplier (e.g., 200 for 2x leverage).

- **Returns**: Address of the newly created position.

---

#### Delete Position

```solidity
function deletePosition(address _lendingPool, address onBehalf) external returns (address)
```

Closes an existing position and transfers remaining assets to the user.

- **Parameters**:
  - `_lendingPool`: Address of the lending pool.
  - `onBehalf`: Address of the position to close.

- **Returns**: Address of the closed position.

---

### Events

| Event Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `PositionCreated`              | Emitted when a new position is created.                                     |
| `PositionDeleted`              | Emitted when a position is deleted.                                         |

---

### Errors

No custom errors are defined, but the contract relies on `require` statements for validation.

---

## Workflow

### Creating a Position

1. The user calls `createPosition` with the desired lending pool, collateral amount, and leverage.
2. The factory deploys a new `Position` contract.
3. Collateral is transferred from the user to the factory and then to the position contract.
4. The position is registered with the lending pool.
5. A flash loan is used to borrow assets and open the leveraged position.
6. An event is emitted to track the position creation.

### Deleting a Position

1. The user calls `deletePosition` with the lending pool and position address.
2. The position is closed, and borrowed assets are repaid.
3. Remaining collateral is transferred back to the user.
4. The position is unregistered from the factory.
5. An event is emitted to track the position deletion.

---

## Conclusion

The `PositionFactory` contract simplifies the process of creating and managing leveraged positions. It handles collateral transfers, position registration, and integrates with `LendingPool` and `Position` contracts to provide a seamless user experience. This contract is essential for users who want to engage in leveraged trading while maintaining control over their positions.