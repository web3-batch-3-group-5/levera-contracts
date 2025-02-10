// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @dev Mutable values
struct PoolParams {
    address loanToken;
    address collateralToken;
    address loanTokenUsdDataFeed;
    address collateralTokenUsdDataFeed;
    string loanTokenName;
    string collateralTokenName;
    string loanTokenSymbol;
    string collateralTokenSymbol;
    address creator;
    bool isActive;
}
