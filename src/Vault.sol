// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IFlashLoanCallback} from "./interfaces/IVault.sol";
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

    address public owner;

    mapping(address => bool) public tokens;
    mapping(address => uint256) public poolBalances;
    mapping(address => bool) public allowedLendingPools;

    modifier onlyLendingPool() {
        if (!allowedLendingPools[msg.sender]) revert NotAuthorized();
        _;
    }

    modifier onlyVerifiedToken(address token) {
        if (!tokens[token]) revert NotAuthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setToken(address token, bool status) external {
        if (msg.sender != owner) revert NotAuthorized();
        tokens[token] = status;
    }

    function setLendingPool(address pool, bool status) external {
        if (msg.sender != owner) revert NotAuthorized();
        allowedLendingPools[pool] = status;
    }

    function deposit(address token, uint256 amount) external onlyVerifiedToken(token) onlyLendingPool {
        if (amount == 0) revert InvalidAmount();

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        poolBalances[msg.sender] += amount;
    }

    function withdraw(address token, uint256 amount) external onlyVerifiedToken(token) onlyLendingPool {
        if (amount == 0) revert InvalidAmount();
        if (poolBalances[msg.sender] < amount) revert InsufficientBalance();

        poolBalances[msg.sender] -= amount;

        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function flashLoan(address token, uint256 amount, bytes calldata data) external onlyVerifiedToken(token) {
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
