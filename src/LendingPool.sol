// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";
import {EventLib} from "./libraries/EventLib.sol";
import {Position} from "./interfaces/ILendingPosition.sol";

contract LendingPosition {}

contract LendingPool {
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InvalidAmount();
    error NoActivePosition();
    error NonZeroActivePosition();
    error TransferReverted();
    error ZeroAddress();

    address public immutable owner;
    bytes32 public immutable contractId;
    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;
    AggregatorV2V3Interface public loanTokenUsdDataFeed;
    AggregatorV2V3Interface public collateralTokenUsdDataFeed;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;
    uint256 lastAccrued;

    mapping(address => uint256) public userSupplyShares;
    mapping(address => mapping(address => Position)) public userPositions;

    constructor(
        IERC20 _loanToken,
        IERC20 _collateralToken,
        AggregatorV2V3Interface _loanTokenUsdPriceFeed,
        AggregatorV2V3Interface _collateralTokenUsdPriceFeed
    ) {
        owner = msg.sender;
        contractId = getContractId(address(_loanToken), address(_collateralToken));
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

    function getContractId(address _loanToken, address _collateralToken) public pure returns (bytes32) {
        return keccak256(abi.encode(_loanToken, _collateralToken));
    }

    function createPosition() public returns (address) {
        LendingPosition onBehalf = new LendingPosition();
        userPositions[msg.sender][address(onBehalf)] =
            Position({collateralAmount: 0, borrowedAmount: 0, timestamp: block.timestamp, isActive: true});

        _updatePosition(address(onBehalf));
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

        _updatePosition(onBehalf);
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
        emit EventLib.UserSupplyShare(address(this), msg.sender, userSupplyShares[msg.sender]);
        emit EventLib.Supply(address(this), msg.sender, userSupplyShares[msg.sender]);
    }

    function withdraw(uint256 shares) public {
        _accrueInterest();

        uint256 amount = (shares * totalSupplyAssets) / totalSupplyShares;
        IERC20(loanToken).transfer(msg.sender, amount);

        totalSupplyAssets -= amount;
        totalSupplyShares -= shares;
        userSupplyShares[msg.sender] -= shares;
        emit EventLib.UserSupplyShare(address(this), msg.sender, userSupplyShares[msg.sender]);
        emit EventLib.Withdraw(address(this), msg.sender, userSupplyShares[msg.sender]);
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        bool success = IERC20(collateralToken).transferFrom(msg.sender, onBehalf, amount);
        if (!success) revert TransferReverted();

        userPositions[msg.sender][onBehalf].collateralAmount += amount;

        _updatePosition(onBehalf);
        emit EventLib.SupplyCollateralByPosition(
            address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]
        );
    }

    function withdrawCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();
        IERC20(collateralToken).transfer(msg.sender, amount);
        userPositions[msg.sender][onBehalf].collateralAmount -= amount;

        _updatePosition(onBehalf);
        emit EventLib.WithdrawCollateralByPosition(
            address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]
        );
    }

    function borrowByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        uint256 collateral = PriceConverterLib.getConversionRate(
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

        emit EventLib.BorrowByPosition(address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]);
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

        _updatePosition(onBehalf);
        emit EventLib.RepayByPosition(address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]);
    }

    function accrueInterest() public {
        _accrueInterest();
    }

    function _updatePosition(address onBehalf) internal {
        Position memory position = userPositions[msg.sender][onBehalf];
        position.timestamp = block.timestamp;

        emit EventLib.UserPosition(
            address(this),
            msg.sender,
            onBehalf,
            position.collateralAmount,
            position.borrowedAmount,
            position.timestamp,
            position.isActive
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

        emit EventLib.AccrueInterest(address(this), borrowRate, interest);
    }
}
