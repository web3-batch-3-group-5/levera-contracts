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
    function loanToken() external view returns (address);
    function collateralToken() external view returns (address);
    function loanTokenUsdDataFeed() external view returns (address);
    function collateralTokenUsdDataFeed() external view returns (address);
    function getContractId() external view returns (bytes32);

    function supply(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function borrow(uint256 amount) external;
    function flashLoan(address token, uint256 amount, bytes calldata data) external;
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
