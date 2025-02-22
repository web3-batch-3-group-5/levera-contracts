// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct PositionParams {
    address loanToken;
    address collateralToken;
    uint256 baseCollateral;
    uint256 effectiveCollateral;
    uint256 borrowShares;
    uint256 lastUpdated;
    uint8 leverage;
    uint8 liquidationPrice;
    uint8 health;
    uint8 ltv;
}

interface IPosition {
    function lendingPool() external view returns (address);
    function baseCollateral() external view returns (uint256);
    function effectiveCollateral() external view returns (uint256);
    function borrowShares() external view returns (uint256);
    function leverage() external view returns (uint8);
    function liquidationPrice() external view returns (uint256);
    function health() external view returns (uint256);
    function ltv() external view returns (uint256);
    function lastUpdated() external view returns (uint256);

    function addLeverage(uint256 amount, uint256 debt) external;
    function onFlashLoan(address token, uint256 amount, bytes calldata data) external;
    function editPosition(address lendingPool, address onBehalf, uint256 baseCollateral, uint8 leverage)
        external
        returns (bool);
    function initialization(uint256 _baseCollateral, uint8 _leverage) external;
}
