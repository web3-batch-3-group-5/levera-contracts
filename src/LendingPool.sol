// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {LendingPosition, Position} from "./LendingPosition.sol";

contract LendingPool {
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InsufficientShares();
    error InvalidAmount();
    error NoActivePosition();
    error NonZeroActivePosition();
    error ZeroAddress();
    error ZeroAmount();

    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;
    AggregatorV2V3Interface internal loanTokenUsdDataFeed;
    AggregatorV2V3Interface internal collateralTokenUsdDataFeed;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;
    uint256 lastAccrued;
    uint256 ltv = 70;

    mapping(address => uint256) public userSupplyShares;
    mapping(address => mapping(address => Position)) public userPositions;

    event UserPosition(
        address indexed caller,
        address indexed onBehalf,
        uint256 collateralAmount,
        uint256 borrowShares,
        uint256 timestamp,
        bool isActive
    );
    event UserSupplyShare(address indexed caller, uint256 supplyShare, uint256 timestamp);

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
            Position({collateralAmount: 0, borrowShares: 0, timestamp: block.timestamp, isActive: true});

        _updatePosition(address(onBehalf));
        return address(onBehalf);
    }

    function getPosition(address onBehalf)
        public
        view
        returns (uint256 collateralAmount, uint256 borrowShares, uint256 timestamp, bool isActive)
    {
        Position storage position = userPositions[msg.sender][onBehalf];
        return (position.collateralAmount, position.borrowShares, position.timestamp, position.isActive);
    }

    function closePosition(address onBehalf) public onlyActivePosition(onBehalf) {
        Position storage position = userPositions[msg.sender][onBehalf];
        if (position.borrowShares != 0 || position.collateralAmount != 0) revert NonZeroActivePosition();

        userPositions[msg.sender][onBehalf].isActive = false;

        _updatePosition(onBehalf);
    }

    function supply(uint256 amount) public {
        if (amount == 0) revert ZeroAmount();
        if (msg.sender == address(0) || address(loanToken) == address(0)) revert ZeroAddress();

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

        // Transfer USDC from sender to contract
        IERC20(loanToken).transferFrom(msg.sender, address(this), amount);

        emit UserSupplyShare(msg.sender, userSupplyShares[msg.sender], block.timestamp);
    }

    function withdraw(uint256 shares) public {
        if (shares == 0) revert ZeroAmount();
        if (shares > userSupplyShares[msg.sender]) revert InsufficientShares();

        _accrueInterest();

        uint256 amount = (shares * totalSupplyAssets) / totalSupplyShares;

        totalSupplyAssets -= amount;
        totalSupplyShares -= shares;
        userSupplyShares[msg.sender] -= shares;

        IERC20(loanToken).transfer(msg.sender, amount);

        emit UserSupplyShare(msg.sender, userSupplyShares[msg.sender], block.timestamp);
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);

        userPositions[msg.sender][onBehalf].collateralAmount += amount;

        _updatePosition(onBehalf);
    }

    function withdrawCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        if (amount > userPositions[msg.sender][onBehalf].collateralAmount) revert InsufficientCollateral();
        _isHealthy(onBehalf);

        IERC20(collateralToken).transfer(msg.sender, amount);
        userPositions[msg.sender][onBehalf].collateralAmount -= amount;

        _updatePosition(onBehalf);
    }

    function borrowByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
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
        userPositions[msg.sender][onBehalf].borrowShares += shares;

        _isHealthy(onBehalf);
        IERC20(loanToken).transfer(msg.sender, amount);
    }

    function repayByPosition(address onBehalf, uint256 shares) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        if (shares == 0 || totalBorrowShares == 0) revert InvalidAmount();

        uint256 amount = (shares * totalBorrowAssets) / totalBorrowShares;
        if (amount == 0) revert InvalidAmount();

        // Reduce borrow shares
        Position storage position = userPositions[msg.sender][onBehalf];
        if (position.borrowShares < shares) revert InvalidAmount();

        position.borrowShares -= shares;
        totalBorrowShares -= shares;
        totalBorrowAssets -= amount;

        // Transfer funds from user
        IERC20(loanToken).transferFrom(msg.sender, address(this), shares);

        _updatePosition(onBehalf);
    }

    function accrueInterest() public {
        _accrueInterest();
    }

    function _updatePosition(address onBehalf) internal {
        Position storage position = userPositions[msg.sender][onBehalf];
        emit UserPosition(
            msg.sender, onBehalf, position.collateralAmount, position.borrowShares, block.timestamp, position.isActive
        );
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

    function _isHealthy(address onBehalf) internal {
        uint256 borrowShares = userPositions[msg.sender][onBehalf].borrowShares;
        uint256 collateral = PriceConverter.getConversionRate(
            userPositions[msg.sender][onBehalf].collateralAmount, collateralTokenUsdDataFeed, loanTokenUsdDataFeed
        );

        // Ensure borrowed doesn't exceed collateral before subtraction
        if (borrowShares >= collateral) revert InsufficientCollateral();

        uint256 allowedBorrowAmount = (collateral - borrowShares) * ltv / 100;
        if (borrowShares > allowedBorrowAmount) revert InsufficientCollateral();
    }
}
