// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IFlashLoanCallback} from "./interfaces/ILendingPool.sol";
import {Test, console} from "forge-std/Test.sol";

contract Vault {
    error NotAuthorized();
    error InvalidAmount();
    error InvalidToken();
    error InsufficientBalance();
    error TransferFailed();
    error FlashLoanFailed();
    error ZeroAmount();
    error InsufficientLiquidity();

    address public loanToken;
    address public collateralToken;
    address public owner;

    mapping(address => uint256) public balances;
    mapping(address => bool) public allowedLendingPools;

    modifier onlyLendingPool() {
        if (!allowedLendingPools[msg.sender]) revert NotAuthorized();
        _;
    }

    constructor(address _loanToken, address _collateralToken, address _owner) {
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        owner = _owner;
    }

    function setLendingPool(address pool, bool status) external {
        if (msg.sender != owner) revert NotAuthorized();
        allowedLendingPools[pool] = status;
    }

    function deposit(uint256 amount) external onlyLendingPool {
        if (amount == 0) revert InvalidAmount();

        bool success = IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external onlyLendingPool {
        if (amount == 0) revert InvalidAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;

        bool success = IERC20(loanToken).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function flashLoan(address token, uint256 amount, bytes calldata data) external {
        if (token != loanToken && token != collateralToken) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();
        console.log(MockERC20(token).balanceOf(address(this)), "here vault balance");
        console.log("vault address", address(this));
        if (MockERC20(token).balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        // Send funds to the borrower
        MockERC20(token).transfer(msg.sender, amount);

        // Call the borrower’s flash loan callback
        IFlashLoanCallback(msg.sender).onFlashLoan(token, amount, data);

        // Ensure repayment
        MockERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}
