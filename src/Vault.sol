// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IFlashLoanCallback} from "./interfaces/IVault.sol";

contract Vault is Ownable {
    error NotAuthorized();
    error InvalidAmount();
    error InvalidToken();
    error InsufficientBalance();
    error TransferFailed();
    error FlashLoanFailed();
    error ZeroAmount();
    error InsufficientLiquidity();

    mapping(address => bool) public tokens;
    mapping(address => uint256) public poolBalances;
    mapping(address => bool) public allowedLendingPools;

    modifier onlyLendingPool() {
        if (!allowedLendingPools[msg.sender]) revert NotAuthorized();
        _;
    }

    modifier onlyVerifiedToken(address token) {
        if (!tokens[token]) revert InvalidToken();
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setToken(address token, bool status) external onlyOwner {
        tokens[token] = status;
    }

    function setLendingPool(address pool, bool status) external onlyOwner {
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

        (bool success,) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, msg.sender, amount));
        if (!success) revert TransferFailed();
    }

    function flashLoan(address token, uint256 amount, bytes calldata data) external onlyVerifiedToken(token) {
        if (amount == 0) revert ZeroAmount();
        if (MockERC20(token).balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        // Send funds to the borrower
        MockERC20(token).transfer(msg.sender, amount);

        // Call the borrower’s flash loan callback
        IFlashLoanCallback(msg.sender).onFlashLoan(token, amount, data);

        // Ensure repayment
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        if (allowance < amount) revert FlashLoanFailed();

        MockERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}
