// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

error ZeroAddress();
error TransferReverted();
error NegativeAnswer();

contract LendingPool {
    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;
    AggregatorV2V3Interface internal loanTokenUsdDataFeed;
    AggregatorV2V3Interface internal collateralTokenUsdDataFeed;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;
    uint256 lastAccrued;

    mapping(address => uint256) public userSupplyShares;
    mapping(address => uint256) public userCollaterals;

    constructor(IERC20 _loanToken, IERC20 _collateralToken, address _loanPriceFeed, address _collateralPriceFeed) {
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        loanTokenUsdDataFeed = _loanPriceFeed;
        collateralTokenUsdDataFeed = _collateralPriceFeed;
        lastAccrued = block.timestamp;
    }

    function supply(uint256 amount) public {
        if (msg.sender != address(0) || address(loanToken) != address(0)) revert ZeroAddress();

        // Transfer USDC from sender to contract
        bool success = IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferReverted();

        _accrueInterest();

        uint256 shares = 0;
        if (totalSupplyAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupplyShares) / totalSupplyAssets;
        }

        totalSupplyAssets += amount;
        totalSupplyShares += shares;
        userSupplyShares[msg.sender] += shares;
    }

    function withdraw(uint256 shares) public {
        _accrueInterest();

        uint256 amount = (shares * totalSupplyAssets) / totalSupplyShares;

        totalSupplyAssets -= amount;
        totalSupplyShares -= shares;
        userSupplyShares[msg.sender] -= shares;
        IERC20(loanToken).transfer(msg.sender, amount);
    }

    function supplyCollateral(uint256 amount) public {
        _accrueInterest();

        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
    }

    function withdrawCollateral(uint256 amount) public {
        _accrueInterest();

        IERC20(collateralToken).transfer(msg.sender, amount);
        userCollaterals[msg.sender] -= amount;
    }

    function borrow(uint256 amount) public {
        uint256 availableLiquidity = IERC20(loanToken).balanceOf(address(this));
        require(availableLiquidity >= amount, "Insufficient liquidity to borrow");

        _accrueInterest();

        uint256 shares = 0;
        if (totalBorrowAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalBorrowShares) / totalBorrowAssets;
        }

        totalBorrowAssets += amount;
        totalBorrowShares += shares;

        IERC20(loanToken).transfer(msg.sender, amount);
    }

    function repay(uint256 shares) public {
        _accrueInterest();

        uint256 amount = (shares * totalBorrowAssets) / totalBorrowShares;
        require(amount > 0, "Invalid repayment amount");

        // Transfer funds from user
        bool success = IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
        require(success, "Repayment transfer failed");

        totalBorrowAssets -= amount;
        totalBorrowShares -= shares;
    }

    function accrueInterest() public {
        _accrueInterest();
    }

    function _accrueInterest() internal {
        uint256 borrowRate = 5;

        uint256 interestPerYear = totalBorrowAssets * borrowRate / 100;
        uint256 elapsedTime = block.timestamp - lastAccrued;

        uint256 interest = (interestPerYear * elapsedTime) / 365 days;

        totalBorrowAssets += interest;
        totalSupplyAssets += interest;

        lastAccrued = block.timestamp;
    }
}
