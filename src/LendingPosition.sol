// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LendingPool} from "./LendingPool.sol";

error InsufficientCollateral();

struct Position {
    uint256 collateralAmount;
    uint256 borrowedAmount;
    uint256 timestamp;
    bool isActive;
}

contract LendingPosition {
    mapping(address => Position) public userPositions;
    LendingPool public lendingPool;

    event PositionCreated(address indexed user, uint256 timestamp);
    event PositionClosed(address indexed user);
    event Repaid(address indexed user, uint256 amount);

    constructor(address _lendingPool) {
        lendingPool = LendingPool(_lendingPool);
    }

    function createPosition() public {
        require(!userPositions[msg.sender].isActive, "Position already exists");

        userPositions[msg.sender] =
            Position({collateralAmount: 0, borrowedAmount: 0, timestamp: block.timestamp, isActive: true});

        emit PositionCreated(msg.sender, block.timestamp);
    }

    function supplyCollateralByPosition(uint256 amount) public {
        // If user has no active position, create one
        if (!userPositions[msg.sender].isActive) {
            createPosition();
        }

        // Ensure position is active before proceeding
        require(userPositions[msg.sender].isActive, "Failed to create position");

        // Call LendingPool to supply collateral
        lendingPool.supplyCollateral(amount);
        userPositions[msg.sender].collateralAmount += amount;
    }

    function borrowByPosition(uint256 amount) public {
        // if (
        //     lendingPool.getConversionRate(amount, loanToken, collateralToken)
        //         >= userPositions[msg.sender].collateralAmount
        // ) revert InsufficientCollateral();
        // Ensure position is active before proceeding
        require(userPositions[msg.sender].isActive, "Failed to create position");

        Position storage position = userPositions[msg.sender];

        // Ensure the borrow amount does not exceed the available collateral (collateralAmount - borrowedAmount)
        /// @lendingPool.getConversionPrice rate
        uint256 allowedBorrowAmount = position.collateralAmount - position.borrowedAmount;
        require(amount <= allowedBorrowAmount, "Borrow amount exceeds available collateral");

        // Borrow from LendingPool
        lendingPool.borrow(amount);

        // Update user's borrowed amount
        userPositions[msg.sender].borrowedAmount += amount;
    }

    function repayByPosition(uint256 amount) public {
        // Ensure user has an active position
        if (!userPositions[msg.sender].isActive) {
            revert("No active position to repay");
        }

        // Ensure user has borrowed funds
        Position storage position = userPositions[msg.sender];
        require(position.borrowedAmount > amount, "Repay amount exceeds borrowed");

        // Update borrowed amount
        position.borrowedAmount -= amount;
        emit Repaid(msg.sender, amount);
    }

    function closePosition() public {
        Position storage position = userPositions[msg.sender];
        require(position.isActive, "No active position");
        require(position.borrowedAmount == 0, "Repay loan first");
        require(position.collateralAmount == 0, "Withdraw collateral first");

        position.isActive = false;
        emit PositionClosed(msg.sender);
    }
}
