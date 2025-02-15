// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {PoolParams} from "../interfaces/ILendingPool.sol";
import {PositionParams} from "../interfaces/ILendingPosition.sol";

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
        uint256 collateralAmount,
        uint256 borrowShares,
        uint256 timestamp,
        bool isActive
    );

    event SupplyCollateralByPosition(
        address indexed lendingPool, address indexed caller, address indexed onBehalf, PositionParams position
    );

    event WithdrawCollateralByPosition(
        address indexed lendingPool, address indexed caller, address indexed onBehalf, PositionParams position
    );

    event BorrowByPosition(
        address indexed lendingPool, address indexed caller, address indexed onBehalf, PositionParams position
    );

    event RepayByPosition(
        address indexed lendingPool, address indexed caller, address indexed onBehalf, PositionParams position
    );

    event AccrueInterest(address indexed lendingPool, uint256 prevBorrowRate, uint256 interest);
}
