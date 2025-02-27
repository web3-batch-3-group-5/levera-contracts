# How It Works: LendingPoolFactory, LendingPool, Position, and PositionFactory Contracts

This document provides a high-level overview of how the **LendingPoolFactory**, **LendingPool**, **Position**, and **PositionFactory** contracts work together to enable decentralized lending, borrowing, and leveraged trading.

---

## Overview

The system consists of four main contracts:

1. **LendingPoolFactory**: A factory contract that creates and manages `LendingPool` contracts. It ensures each lending pool is unique based on the loan token and collateral token pair.
2. **LendingPool**: A decentralized lending and borrowing platform where users can supply assets, borrow against collateral, and earn interest.
3. **Position**: Represents a leveraged position in a lending pool. Users can open, manage, and close positions by supplying collateral, borrowing assets, and adjusting leverage.
4. **PositionFactory**: A factory contract that creates and manages `Position` contracts. It handles collateral transfers, position registration, and emits events for tracking.

---

## Workflow

### 1. **Creating a Lending Pool**

1. **User Interaction**:
   - A user calls the `createLendingPool` function in the **LendingPoolFactory** contract, specifying the loan token, collateral token, price feeds, liquidation threshold, interest rate, and position type.

2. **Pool Creation**:
   - The factory deploys a new **LendingPool** contract.
   - The pool is uniquely identified by a hash of the loan token and collateral token addresses.
   - The pool is registered in the factory's tracking system.

3. **Event Emission**:
   - The `CreateLendingPool` event is emitted to track the new lending pool.

---

### 2. **Supplying and Borrowing in a Lending Pool**

1. **Supply Assets**:
   - Users can call the `supply` function in the **LendingPool** contract to deposit assets into the pool.
   - They receive shares proportional to their deposit, which represent their stake in the pool.

2. **Borrow Assets**:
   - Users can call the `borrowByPosition` function to borrow assets by providing collateral.
   - The borrowed amount is calculated based on the collateral value and liquidation threshold.

3. **Interest Accrual**:
   - Interest is accrued on borrowed assets and distributed to suppliers over time.

---

### 3. **Opening a Leveraged Position**

1. **User Interaction**:
   - A user calls the `createPosition` function in the **PositionFactory** contract, specifying the lending pool, collateral amount, and leverage.

2. **Position Creation**:
   - The **PositionFactory** deploys a new **Position** contract.
   - Collateral is transferred from the user to the factory and then to the position contract.
   - The position is registered with the lending pool.

3. **Leverage Adjustment**:
   - The **Position** contract uses a flash loan to borrow assets and open the leveraged position.
   - The borrowed assets are swapped for additional collateral, increasing the effective collateral and leverage.

4. **Event Emission**:
   - The `PositionCreated` event is emitted to track the new position.

---

### 4. **Managing a Position**

1. **Adding Collateral**:
   - Users can call the `addCollateral` function in the **Position** contract to add more collateral to their position.
   - This increases the base collateral and effective collateral, improving the position's health.

2. **Withdrawing Collateral**:
   - Users can call the `withdrawCollateral` function to withdraw collateral from their position.
   - The position's health is checked to ensure it remains safe.

3. **Adjusting Leverage**:
   - Users can call the `updateLeverage` function to increase or decrease the leverage of their position.
   - Flash loans are used to adjust the borrowed assets and collateral accordingly.

4. **Risk Management**:
   - The **Position** contract continuously tracks the liquidation price, health factor, and loan-to-value (LTV) ratio.
   - If the position becomes at risk of liquidation, transactions will revert to protect the user.

---

### 5. **Closing a Position**

1. **User Interaction**:
   - A user calls the `deletePosition` function in the **PositionFactory** contract, specifying the lending pool and position address.

2. **Position Closure**:
   - The **Position** contract repays the borrowed assets and withdraws the remaining collateral.
   - The position is unregistered from the lending pool.

3. **Asset Transfer**:
   - The remaining assets are transferred back to the user.

4. **Event Emission**:
   - The `PositionDeleted` event is emitted to track the closed position.

---

### 6. **Discarding a Lending Pool**

1. **User Interaction**:
   - The owner or creator of a lending pool calls the `discardLendingPool` function in the **LendingPoolFactory** contract.

2. **Pool Removal**:
   - The lending pool is deactivated and removed from the factory's tracking system.
   - All associated positions must be closed before discarding the pool.

3. **Event Emission**:
   - The `DiscardLendingPool` event is emitted to track the removal.

---

## Key Interactions

### **LendingPoolFactory**

- **Create Lending Pool**: Deploys a new **LendingPool** contract.
- **Store Lending Pool**: Tracks an existing lending pool.
- **Discard Lending Pool**: Removes a lending pool from the factory's tracking system.

### **LendingPool**

- **Supply**: Users supply assets to the pool and earn interest.
- **Borrow**: Users borrow assets by providing collateral.
- **Flash Loans**: Users can perform flash loans for leverage adjustments.
- **Interest Accrual**: Interest is accrued on borrowed assets and distributed to suppliers.

### **Position**

- **Open Position**: Users open a leveraged position by supplying collateral and borrowing assets.
- **Add/Remove Collateral**: Users can adjust their collateral to manage risk.
- **Adjust Leverage**: Users can increase or decrease the leverage of their position.
- **Close Position**: Users can close their position, repay borrowed assets, and withdraw remaining collateral.

### **PositionFactory**

- **Create Position**: Deploys a new **Position** contract and opens a leveraged position.
- **Delete Position**: Closes an existing position and transfers remaining assets to the user.
- **Collateral Management**: Handles collateral transfers and approvals.

---

## Risk Management

- **Liquidation Price**: The price at which the position can be liquidated.
- **Health Factor**: A measure of the position's safety. If it falls below 1, the position is at risk of liquidation.
- **Loan-to-Value (LTV) Ratio**: The ratio of borrowed assets to collateral value.

---

## Conclusion

The **LendingPoolFactory**, **LendingPool**, **Position**, and **PositionFactory** contracts work together to provide a decentralized platform for lending, borrowing, and leveraged trading. Users can create lending pools, open and manage leveraged positions, and adjust their risk exposure. The system is designed to be secure, efficient, and user-friendly, making it an ideal choice for decentralized finance (DeFi) applications.