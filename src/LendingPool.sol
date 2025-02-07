// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {LendingPosition, Position} from "./LendingPosition.sol";

contract LendingPool {
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InvalidAmount();
    error NoActivePosition();
    error NonZeroActivePosition();
    error TransferReverted();
    error ZeroAddress();

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

    event Repaid(
        address indexed caller,
        address indexed onBehalf,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 timestamp,
        bool isActive
    );
    event PositionCreated(
        address indexed caller,
        address indexed onBehalf,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 timestamp,
        bool isActive
    );
    event PositionClosed(
        address indexed caller,
        address indexed onBehalf,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 timestamp,
        bool isActive
    );
    event Supply(address indexed caller, uint256 supplyShare);

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

    modifier onlyActivePosition(address onBehalf) {
        if (!userPositions[msg.sender][onBehalf].isActive) revert NoActivePosition();
        _;
    }

    function createPosition() public returns (address) {
        LendingPosition onBehalf = new LendingPosition();
        userPositions[msg.sender][address(onBehalf)] =
            Position({collateralAmount: 0, borrowedAmount: 0, timestamp: block.timestamp, isActive: true});
        emit PositionCreated(msg.sender, address(onBehalf), 0, 0, block.timestamp, true);
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

    function closePosition(address onBehalf) public onlyActivePosition(onBehalf) {
        Position storage position = userPositions[msg.sender][onBehalf];
        if (position.borrowedAmount != 0 || position.collateralAmount != 0) revert NonZeroActivePosition();

        userPositions[msg.sender][onBehalf].isActive = false;
        emit PositionClosed(msg.sender, onBehalf, 0, 0, block.timestamp, false);
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
        emit Supply(msg.sender, userSupplyShares[msg.sender]);
    }

    function withdraw(uint256 shares) public {
        _accrueInterest();

        uint256 amount = (shares * totalSupplyAssets) / totalSupplyShares;

        totalSupplyAssets -= amount;
        totalSupplyShares -= shares;
        userSupplyShares[msg.sender] -= shares;
        IERC20(loanToken).transfer(msg.sender, amount);
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        bool success = IERC20(collateralToken).transferFrom(msg.sender, onBehalf, amount);
        if (!success) revert TransferReverted();

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
        if (allowedBorrowAmount < amount) revert InsufficientCollateral();

        uint256 availableLiquidity = IERC20(loanToken).balanceOf(address(this));
        if (availableLiquidity < amount) revert InsufficientLiquidity();

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
        if (amount <= 0) revert InvalidAmount();

        // Transfer funds from user
        bool success = IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferReverted();

        userPositions[msg.sender][onBehalf].borrowedAmount -= amount;
        totalBorrowAssets -= amount;
        totalBorrowShares -= shares;

        Position memory position = userPositions[msg.sender][onBehalf];
        emit Repaid(
            msg.sender, address(onBehalf), position.collateralAmount, position.borrowedAmount, block.timestamp, true
        );
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
