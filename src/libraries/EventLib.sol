// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {PoolParams} from "../interfaces/ILendingPool.sol";

library EventLib {
    event AllLendingPool(
        address indexed lendingPool, address loanToken, address collateralToken, address creator, bool isActive
    );

    event CreateLendingPool(
        address indexed lendingPool, address loanToken, address collateralToken, address creator, bool isActive
    );

    event StoreLendingPool(
        address indexed lendingPool, address loanToken, address collateralToken, address creator, bool isActive
    );

    event DiscardLendingPool(address indexed lendingPool);

    event LendingPoolStat(
        address indexed lendingPool,
        address loanToken,
        address collateralToken,
        uint256 totalSupplyAssets,
        uint256 totalSupplyShares,
        uint256 totalBorrowAssets,
        uint256 totalBorrowShares,
        uint256 totalCollateral
    );

    event UserSupplyShare(address indexed lendingPool, address indexed caller, uint256 supplyShare);

    event Supply(address indexed lendingPool, address indexed caller, uint256 supplyShare);

    event Withdraw(address indexed lendingPool, address indexed caller, uint256 supplyShare);

    event UserPosition(
        address indexed lendingPool,
        address indexed caller,
        address onBehalf,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint256 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv
    );

    event SupplyCollateral(
        address indexed lendingPool,
        address indexed caller,
        address onBehalf,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint256 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv
    );

    event WithdrawCollateral(
        address indexed lendingPool,
        address indexed caller,
        address onBehalf,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint256 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv
    );

    event Borrow(
        address indexed lendingPool,
        address indexed caller,
        address onBehalf,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint256 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv
    );

    event Repay(
        address indexed lendingPool,
        address indexed caller,
        address onBehalf,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint256 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv
    );

    event AccrueInterest(address indexed lendingPool, uint256 prevBorrowRate, uint256 interest);

    event PositionCreated(
        address lendingPool, address caller, address positionAddress, uint256 baseCollateral, uint256 leverage
    );

    event PositionDeleted(address lendingPool, address caller, address onBehalf);
}
