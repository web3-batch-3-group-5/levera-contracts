# LendingPool Smart Contract Documentation

## Overview

The `LendingPool` contract is a decentralized lending and borrowing platform built on Ethereum. It allows users to supply assets, borrow against collateral, and earn interest. The contract supports flash loans, interest accrual, and liquidation mechanisms. It is designed to be secure, efficient, and flexible, with support for different types of collateral and loan tokens.

---

## Key Features

1. **Supply and Withdraw Assets**: Users can supply assets to the pool and earn interest. They can also withdraw their supplied assets at any time.
2. **Borrow and Repay**: Users can borrow assets by providing collateral. They must repay the borrowed amount along with interest.
3. **Flash Loans**: The contract supports flash loans, allowing users to borrow assets without collateral, provided the loan is repaid within the same transaction.
4. **Interest Accrual**: Interest is accrued on borrowed assets and distributed to suppliers.
5. **Liquidation Mechanism**: The contract includes a liquidation threshold to ensure the safety of the pool.
6. **Position Management**: Users can register and unregister positions, and manage collateral and borrowing for each position.

---

## Contract Details

### State Variables

| Variable Name                  | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `router`                       | Address of the router contract.                                             |
| `owner`                        | Address of the contract owner.                                              |
| `creator`                      | Address of the contract creator.                                            |
| `contractId`                   | Unique identifier for the contract.                                         |
| `loanToken`                    | The token used for lending and borrowing.                                   |
| `collateralToken`              | The token used as collateral.                                               |
| `loanTokenUsdDataFeed`         | Chainlink price feed for the loan token.                                    |
| `collateralTokenUsdDataFeed`   | Chainlink price feed for the collateral token.                              |
| `positionType`                 | Type of position (e.g., long, short).                                       |
| `totalSupplyAssets`            | Total amount of assets supplied to the pool.                                |
| `totalSupplyShares`            | Total number of shares representing the supplied assets.                    |
| `totalBorrowAssets`            | Total amount of assets borrowed from the pool.                              |
| `totalBorrowShares`            | Total number of shares representing the borrowed assets.                    |
| `totalCollateral`              | Total amount of collateral locked in the pool.                              |
| `ltp`                          | Liquidation Threshold Percentage.                                           |
| `interestRate`                 | Interest rate applied to borrowed assets.                                   |
| `lastAccrued`                  | Timestamp of the last interest accrual.                                     |
| `userPositions`                | Mapping of user addresses to their active positions.                        |
| `userSupplyShares`             | Mapping of user addresses to their supply shares.                           |

---

### Modifiers

| Modifier Name                  | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `onlyActivePosition(address onBehalf)` | Ensures that the user has an active position.                              |

---

### Functions

#### Constructor

```solidity
constructor(
    IERC20 _loanToken,
    IERC20 _collateralToken,
    AggregatorV2V3Interface _loanTokenUsdPriceFeed,
    AggregatorV2V3Interface _collateralTokenUsdPriceFeed,
    address _router,
    uint256 _ltp,
    uint256 _interestRate,
    PositionType _positionType,
    address _creator
)
```

Initializes the contract with the loan token, collateral token, price feeds, router, liquidation threshold, interest rate, position type, and creator address.

---

#### Supply

```solidity
function supply(uint256 amount) public
```

Allows users to supply assets to the pool. The amount of shares issued is proportional to the amount of assets supplied.

---

#### Withdraw

```solidity
function withdraw(uint256 shares) public
```

Allows users to withdraw their supplied assets by burning their shares.

---

#### Register Position

```solidity
function registerPosition(address onBehalf) public
```

Registers a new position for a user.

---

#### Unregister Position

```solidity
function unregisterPosition(address onBehalf) public
```

Unregisters a position for a user.

---

#### Supply Collateral by Position

```solidity
function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf)
```

Allows users to supply collateral for their active position.

---

#### Withdraw Collateral by Position

```solidity
function withdrawCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf)
```

Allows users to withdraw collateral from their active position.

---

#### Borrow by Position

```solidity
function borrowByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) returns (uint256 shares)
```

Allows users to borrow assets against their collateral. The amount of shares issued is proportional to the amount borrowed.

---

#### Repay by Position

```solidity
function repayByPosition(address onBehalf, uint256 shares) public onlyActivePosition(onBehalf)
```

Allows users to repay their borrowed assets by burning their shares.

---

#### Accrue Interest

```solidity
function accrueInterest() public
```

Accrues interest on borrowed assets and updates the total supply and borrow amounts.

---

#### Flash Loan

```solidity
function flashLoan(address token, uint256 amount, bytes calldata data) external
```

Allows users to perform a flash loan. The loan must be repaid within the same transaction.

---

#### Get Liquidation Price

```solidity
function getLiquidationPrice(uint256 effectiveCollateral, uint256 borrowAmount) external view returns (uint256)
```

Returns the liquidation price for a given amount of collateral and borrowed assets.

---

#### Get Health

```solidity
function getHealth(uint256 effectiveCollateralPrice, uint256 borrowAmount) external view returns (uint256)
```

Returns the health factor for a given amount of collateral and borrowed assets.

---

#### Get LTV

```solidity
function getLTV(uint256 effectiveCollateralPrice, uint256 borrowAmount) external pure returns (uint256)
```

Returns the Loan-to-Value (LTV) ratio for a given amount of collateral and borrowed assets.

---

### Internal Functions

#### `_accrueInterest()`

Accrues interest on borrowed assets and updates the total supply and borrow amounts.

#### `_indexLendingPool()`

Emits an event with the current state of the lending pool.

---

### Events

| Event Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `UserSupplyShare`              | Emitted when a user's supply shares change.                                 |
| `Supply`                       | Emitted when assets are supplied to the pool.                               |
| `Withdraw`                     | Emitted when assets are withdrawn from the pool.                            |
| `AccrueInterest`               | Emitted when interest is accrued.                                           |
| `LendingPoolStat`              | Emitted when the lending pool's state is updated.                           |

---

### Errors

| Error Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `InsufficientCollateral`       | Thrown when there is insufficient collateral.                               |
| `InsufficientLiquidity`        | Thrown when there is insufficient liquidity.                                |
| `InsufficientShares`           | Thrown when there are insufficient shares.                                  |
| `InvalidAmount`                | Thrown when an invalid amount is provided.                                  |
| `NoActivePosition`             | Thrown when there is no active position.                                    |
| `NonZeroActivePosition`        | Thrown when there is an active position.                                    |
| `ZeroAddress`                  | Thrown when a zero address is provided.                                     |
| `ZeroAmount`                   | Thrown when a zero amount is provided.                                      |
| `FlashLoanFailed`              | Thrown when a flash loan fails.                                             |

---

## Conclusion

The `LendingPool` contract is a robust and flexible solution for decentralized lending and borrowing. It includes features such as interest accrual, flash loans, and a liquidation mechanism to ensure the safety and efficiency of the pool. The contract is designed to be secure and easy to use, making it an ideal choice for decentralized finance (DeFi) applications.