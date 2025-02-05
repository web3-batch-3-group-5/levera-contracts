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

    function closePosition() public {
        Position storage position = userPositions[msg.sender];
        require(position.isActive, "No active position");
        require(position.borrowedAmount == 0, "Repay loan first");
        require(position.collateralAmount == 0, "Withdraw collateral first");

        position.isActive = false;
        emit PositionClosed(msg.sender);
    }
}
