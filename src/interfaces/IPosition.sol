// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct PositionParams {
    address loanToken;
    address collateralToken;
    uint256 baseCollateral;
    uint256 effectiveCollateral;
    uint256 borrowShares;
    uint256 lastUpdated;
    uint256 leverage;
    uint256 liquidationPrice;
    uint256 health;
    uint256 ltv;
}

interface IPosition {
    function lendingPool() external view returns (address);
    function baseCollateral() external view returns (uint256);
    function effectiveCollateral() external view returns (uint256);
    function borrowShares() external view returns (uint256);
    function leverage() external view returns (uint256);
    function liquidationPrice() external view returns (uint256);
    function health() external view returns (uint256);
    function ltv() external view returns (uint256);
    function lastUpdated() external view returns (uint256);

    function addCollateral(uint256 amount) external;
    function addLeverage(uint256 amount, uint256 debt) external;
    function onFlashLoan(address token, uint256 amount, bytes calldata data) external;
    function editPosition(address lendingPool, address onBehalf, uint256 baseCollateral, uint256 leverage)
        external
        returns (bool);
    function openPosition() external;
    function closePosition() external returns (uint256);
    function liquidatePosition() external returns (uint256);
}

enum PositionStatus {
    OPEN,
    CLOSED,
    LIQUIDATED
}
