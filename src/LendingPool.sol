// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {LendingPosition, Position} from "./LendingPosition.sol";

error ZeroAddress();
error TransferReverted();

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
    mapping(address => mapping(address => Position)) public userPositions;

    event Repaid(address indexed user, uint256 amount);
    event PositionCreated(address indexed user, uint256 timestamp);
    event PositionClosed(address indexed user);

    constructor(
        IERC20 _loanToken,
        IERC20 _collateralToken,
        AggregatorV2V3Interface _loanTokenUsdPriceFeed,
        AggregatorV2V3Interface _collateralTokenUsdPriceFeed
    ) {
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        loanTokenUsdDataFeed = _loanTokenUsdPriceFeed;
        collateralTokenUsdDataFeed = _collateralTokenUsdPriceFeed;
        lastAccrued = block.timestamp;
    }

    function createPosition() public returns (address) {
        LendingPosition onBehalf = new LendingPosition();
        userPositions[msg.sender][address(onBehalf)] =
            Position({collateralAmount: 0, borrowedAmount: 0, timestamp: block.timestamp, isActive: true});
        emit PositionCreated(msg.sender, block.timestamp);
        return address(onBehalf);
    }

    function getPosition(address onBehalf)
        public
        view
        returns (uint256 collateralAmount, uint256 borrowedAmount, uint256 timestamp, bool isActive)
    {
        Position storage position = userPositions[msg.sender][onBehalf];
        return (position.collateralAmount, position.borrowedAmount, position.timestamp, position.isActive);
    }

    function closePosition(address onBehalf) public {
        Position storage position = userPositions[msg.sender][onBehalf];
        require(position.isActive, "No active position");
        require(position.borrowedAmount == 0, "Repay loan first");
        require(position.collateralAmount == 0, "Withdraw collateral first");

        userPositions[msg.sender][onBehalf].isActive = false;
        emit PositionClosed(msg.sender);
    }

    function supply(uint256 amount) public {
        if (msg.sender == address(0) || address(loanToken) == address(0)) revert ZeroAddress();

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

    modifier onlyActivePosition(address onBehalf) {
        require(userPositions[msg.sender][onBehalf].isActive, "User has no active position");
        _;
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        bool success = IERC20(collateralToken).transferFrom(msg.sender, onBehalf, amount);
        require(success, "Transfer failed");

        userPositions[msg.sender][onBehalf].collateralAmount += amount;
    }

    function withdrawCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();
        IERC20(collateralToken).transfer(msg.sender, amount);
        userPositions[msg.sender][onBehalf].collateralAmount -= amount;
    }

    function borrowByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        uint256 collateral = PriceConverter.getConversionRate(
            userPositions[msg.sender][onBehalf].collateralAmount, collateralTokenUsdDataFeed, loanTokenUsdDataFeed
        );

        uint256 allowedBorrowAmount = collateral - userPositions[msg.sender][onBehalf].borrowedAmount;
        require(allowedBorrowAmount >= amount, "Borrow amount exceeds available collateral");

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
        userPositions[msg.sender][onBehalf].borrowedAmount += amount;

        IERC20(loanToken).transfer(msg.sender, amount);
    }

    function repayByPosition(address onBehalf, uint256 shares) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        uint256 amount = (shares * totalBorrowAssets) / totalBorrowShares;
        require(amount > 0, "Invalid repayment amount");

        // Transfer funds from user
        bool success = IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
        require(success, "Repayment transfer failed");

        userPositions[msg.sender][onBehalf].borrowedAmount -= amount;
        totalBorrowAssets -= amount;
        totalBorrowShares -= shares;
        emit Repaid(msg.sender, amount);
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
