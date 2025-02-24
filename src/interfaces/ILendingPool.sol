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

interface ILendingPool {
    function creator() external view returns (address);
    function owner() external view returns (address);
    function contractId() external view returns (bytes32);
    function loanToken() external view returns (address);
    function collateralToken() external view returns (address);
    function loanTokenUsdDataFeed() external view returns (address);
    function collateralTokenUsdDataFeed() external view returns (address);
    function positionType() external view returns (PositionType);

    function totalSupplyAssets() external view returns (uint256);
    function totalSupplyShares() external view returns (uint256);
    function totalBorrowAssets() external view returns (uint256);
    function totalBorrowShares() external view returns (uint256);
    function totalCollateral() external view returns (uint256);
    function ltp() external view returns (uint8);
    function interestRate() external view returns (uint8);
    function userSupplyShares(address user) external view returns (uint256);
    function userPositions(address onBehalf) external view returns (bool);

    function registerPosition(address onBehalf) external;
    function unregisterPosition(address onBehalf) external;
    function supply(uint256 amount) external;
    function withdraw(uint256 shares) external;
    function supplyCollateralByPosition(address onBehalf, uint256 amount) external;
    function withdrawCollateralByPosition(address onBehalf, uint256 amount) external;
    function borrowByPosition(address onBehalf, uint256 amount) external returns (uint256);
    function repayByPosition(address onBehalf, uint256 amount) external;
    function accrueInterest() external;
    function flashLoan(address token, uint256 amount, bytes calldata data) external;

    function getLiquidationPrice(uint256 effectiveCollateral, uint256 borrowAmount) external view returns (uint8);
    function getHealth(uint256 effectiveCollateral, uint256 borrowAmount) external view returns (uint8);
    function getLTV(uint256 effectiveCollateral, uint256 borrowAmount) external pure returns (uint8);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

enum PositionType {
    LONG,
    SHORT
}
