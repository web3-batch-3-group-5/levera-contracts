// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct PositionParams {
    uint256 collateralAmount;
    uint256 borrowShares;
    uint256 timestamp;
    bool isActive;
}
