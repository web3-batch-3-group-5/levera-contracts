// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {PoolParams} from "../interfaces/ILendingPool.sol";

library EventLib {
    event AllToken(address tokenAddr, string name, string symbol, uint8 decimals, bool isActive);

    // Lending Pool Tables
    event AllLendingPool(
        address lendingPoolAddr,
        address loanToken,
        address collateralToken,
        uint8 positionType,
        address creator,
        bool isActive
    );
    event LendingPoolStat(
        address indexed lendingPoolAddr,
        uint256 totalSupplyAssets,
        uint256 totalSupplyShares,
        uint256 totalBorrowAssets,
        uint256 totalBorrowShares,
        uint256 totalCollateral,
        uint256 ltp,
        uint256 interestRate
    );
    event UserSupplyShare(address lendingPoolAddr, address caller, uint256 supplyShares);

    // Lending Pool Events
    event CreateLendingPool(address lendingPoolAddr);
    event StoreLendingPool(address lendingPoolAddr);
    event DiscardLendingPool(address lendingPoolAddr);
    event Supply(address lendingPoolAddr, address caller, uint256 supplyShares);
    event Withdraw(address lendingPoolAddr, address caller, uint256 supplyShares);
    event AccrueInterest(address lendingPoolAddr, uint256 prevInterest, uint256 interest);

    // Position Table
    event UserPosition(
        address indexed lendingPoolAddr,
        address indexed caller,
        address positionAddr,
        uint256 baseCollateral,
        uint256 totalCollateral,
        uint256 borrowShares,
        uint256 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv,
        uint8 status
    );

    // Position Events
    event CreatePosition(address lendingPoolAddr, address caller, address positionAddr);
    event DeletePosition(address lendingPoolAddr, address caller, address positionAddr);
    event SupplyCollateral(
        address lendingPoolAddr,
        address caller,
        address positionAddr,
        uint256 totalCollateral,
        uint256 borrowShares,
        uint256 leverage
    );
    event WithdrawCollateral(
        address lendingPoolAddr,
        address caller,
        address positionAddr,
        uint256 totalCollateral,
        uint256 borrowShares,
        uint256 leverage
    );
    event Borrow(
        address lendingPoolAddr,
        address caller,
        address positionAddr,
        uint256 totalCollateral,
        uint256 borrowShares,
        uint256 leverage
    );
    event Repay(
        address lendingPoolAddr,
        address caller,
        address positionAddr,
        uint256 totalCollateral,
        uint256 borrowShares,
        uint256 leverage
    );
    event Liquidate(
        address lendingPoolAddr,
        address caller,
        address positionAddr,
        uint256 baseCollateral,
        uint256 totalCollateral,
        uint256 borrowShares,
        uint256 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv
    );
}
