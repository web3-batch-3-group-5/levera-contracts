# LendingPoolFactory Smart Contract Documentation

## Overview

The `LendingPoolFactory` contract is responsible for creating, managing, and tracking `LendingPool` contracts. It allows users to deploy new lending pools, store existing ones, and update their status. The factory ensures that each lending pool is unique based on the loan token and collateral token pair. It also provides utility functions to fetch token details and validate contracts.

---

## Key Features

1. **Create Lending Pools**: Deploys new `LendingPool` contracts with specified parameters.
2. **Store Existing Lending Pools**: Allows the factory to track existing lending pools.
3. **Update Lending Pool Status**: Enables the activation or deactivation of lending pools.
4. **Discard Lending Pools**: Removes lending pools from the factory's tracking system.
5. **Token Metadata Utilities**: Provides functions to fetch token names and symbols.
6. **Contract Validation**: Ensures that only valid contracts are registered as lending pools.

---

## Contract Details

### State Variables

| Variable Name                  | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `router`                       | Address of the router contract.                                             |
| `owner`                        | Address of the contract owner.                                              |
| `lendingPoolIds`               | Mapping of pool IDs (hash of loan and collateral tokens) to pool addresses. |
| `lendingPools`                 | Mapping of lending pool addresses to their activation status.               |
| `createdLendingPools`          | Array of all created lending pool addresses.                                |

---

### Modifiers

| Modifier Name                  | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `canUpdate(address _lendingPool)` | Ensures the caller is authorized to update the lending pool.               |
| `isExist(address _lendingPool)`  | Ensures the lending pool exists in the factory.                            |

---

### Functions

#### Constructor

```solidity
constructor(address _router)
```

Initializes the factory with the router address and sets the owner to the deployer.

---

#### Create Lending Pool

```solidity
function createLendingPool(
    address loanToken,
    address collateralToken,
    address loanTokenUsdDataFeed,
    address collateralTokenUsdDataFeed,
    uint256 liquidationThresholdPercentage,
    uint256 interestRate,
    PositionType positionType
) external returns (address)
```

Deploys a new `LendingPool` contract with the specified parameters. The pool is uniquely identified by the loan token and collateral token pair.

- **Parameters**:
  - `loanToken`: Address of the loan token.
  - `collateralToken`: Address of the collateral token.
  - `loanTokenUsdDataFeed`: Chainlink price feed for the loan token.
  - `collateralTokenUsdDataFeed`: Chainlink price feed for the collateral token.
  - `liquidationThresholdPercentage`: Liquidation threshold percentage.
  - `interestRate`: Interest rate for borrowing.
  - `positionType`: Type of position (e.g., long, short).

- **Returns**: Address of the newly created lending pool.

---

#### Update Lending Pool Status

```solidity
function updateLendingPoolStatus(address _lendingPool, bool _status)
    public
    isExist(_lendingPool)
    canUpdate(_lendingPool)
```

Updates the activation status of a lending pool.

- **Parameters**:
  - `_lendingPool`: Address of the lending pool.
  - `_status`: New status (true for active, false for inactive).

---

#### Store Lending Pool

```solidity
function storeLendingPool(address _lendingPool) external
```

Stores an existing lending pool in the factory. Validates the pool and ensures it is not already registered.

- **Parameters**:
  - `_lendingPool`: Address of the lending pool to store.

---

#### Discard Lending Pool

```solidity
function discardLendingPool(address _lendingPool)
    external
    isExist(_lendingPool)
    canUpdate(_lendingPool)
```

Removes a lending pool from the factory's tracking system.

- **Parameters**:
  - `_lendingPool`: Address of the lending pool to discard.

---

#### Get Token Name

```solidity
function getTokenName(address _token) public view returns (string memory)
```

Returns the name of a token.

- **Parameters**:
  - `_token`: Address of the token.

- **Returns**: Token name or "Unknown" if not available.

---

#### Get Token Symbol

```solidity
function getTokenSymbol(address _token) public view returns (string memory)
```

Returns the symbol of a token.

- **Parameters**:
  - `_token`: Address of the token.

- **Returns**: Token symbol or "UNKNOWN" if not available.

---

#### Is Contract

```solidity
function isContract(address account) internal view returns (bool)
```

Checks if an address is a contract.

- **Parameters**:
  - `account`: Address to check.

- **Returns**: True if the address is a contract, false otherwise.

---

### Internal Functions

#### `_indexLendingPool(address _lendingPool)`

Emits an event with the details of a lending pool.

---

### Events

| Event Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `CreateLendingPool`            | Emitted when a new lending pool is created.                                 |
| `StoreLendingPool`             | Emitted when an existing lending pool is stored in the factory.             |
| `DiscardLendingPool`           | Emitted when a lending pool is discarded.                                   |
| `AllLendingPool`               | Emitted when a lending pool is indexed.                                     |

---

### Errors

| Error Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `NotALendingPool`              | Thrown when the provided address is not a valid lending pool.               |
| `PoolAlreadyCreated`           | Thrown when a lending pool with the same token pair already exists.         |
| `PoolNotFound`                 | Thrown when the specified lending pool does not exist.                      |
| `Unauthorized`                 | Thrown when the caller is not authorized to perform the action.             |

---

## Conclusion

The `LendingPoolFactory` contract is a central hub for creating and managing lending pools. It ensures the uniqueness of pools based on token pairs, provides utilities for token metadata, and maintains a registry of all deployed pools. This contract is essential for scaling decentralized lending and borrowing platforms.