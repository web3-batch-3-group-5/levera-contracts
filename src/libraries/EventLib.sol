// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {PoolParams} from "../interfaces/ILendingPool.sol";

library EventLib {
    event AllLendingPool(
        address indexed lendingPool,
        address loanToken,
        address collateralToken,
        address loanTokenUsdDataFeed,
        address collateralTokenUsdDataFeed,
        string loanTokenName,
        string collateralTokenName,
        string loanTokenSymbol,
        string collateralTokenSymbol,
        address creator,
        bool isActive
    );

    event CreateLendingPool(address indexed lendingPool, PoolParams poolParams);

    event StoreLendingPool(address indexed lendingPool, PoolParams poolParams);

    event DiscardLendingPool(address indexed lendingPool);

    event UserSupplyShare(address indexed lendingPool, address indexed caller, uint256 supplyShare);

    event Supply(address indexed lendingPool, address indexed caller, uint256 supplyShare);

    event Withdraw(address indexed lendingPool, address indexed caller, uint256 supplyShare);

    event UserPosition(
        address indexed lendingPool,
        address indexed caller,
        address indexed onBehalf,
        address loanToken,
        address collateralToken,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint256 timestamp,
        uint8 leverage,
        uint256 liquidationPrice,
        uint256 health,
        uint256 ltv
    );

    event SupplyCollateral(
        address indexed lendingPool,
        address indexed caller,
        address indexed onBehalf,
        address loanToken,
        address collateralToken,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint8 leverage,
        uint8 liquidationPrice,
        uint8 health,
        uint8 ltv
    );

    event WithdrawCollateral(
        address indexed lendingPool,
        address indexed caller,
        address indexed onBehalf,
        address loanToken,
        address collateralToken,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint8 leverage,
        uint8 liquidationPrice,
        uint8 health,
        uint8 ltv
    );

    event Borrow(
        address indexed lendingPool,
        address indexed caller,
        address indexed onBehalf,
        address loanToken,
        address collateralToken,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint8 leverage,
        uint8 liquidationPrice,
        uint8 health,
        uint8 ltv
    );

    event Repay(
        address indexed lendingPool,
        address indexed caller,
        address indexed onBehalf,
        address loanToken,
        address collateralToken,
        uint256 baseCollateral,
        uint256 effectiveCollateral,
        uint256 borrowShares,
        uint8 leverage,
        uint8 liquidationPrice,
        uint8 health,
        uint8 ltv
    );

    event AccrueInterest(address indexed lendingPool, uint256 prevBorrowRate, uint256 interest);
}
