// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";
import {EventLib} from "./libraries/EventLib.sol";
import {PositionParams} from "./interfaces/IPosition.sol";
import {PositionType} from "./interfaces/ILendingPool.sol";

contract LendingPosition {}

interface IFlashLoanCallback {
    function onFlashLoan(address token, uint256 amount, bytes calldata data) external;
}

contract LendingPool {
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InsufficientShares();
    error InvalidAmount();
    error NoActivePosition();
    error NonZeroActivePosition();
    error ZeroAddress();
    error ZeroAmount();
    error FlashLoanFailed();

    address public immutable owner;
    bytes32 public immutable contractId;
    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;
    AggregatorV2V3Interface public loanTokenUsdDataFeed;
    AggregatorV2V3Interface public collateralTokenUsdDataFeed;
    PositionType public positionType;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;
    uint256 public ltv = 70;
    uint8 public borrowRate = 5;
    uint8 public liquidationThresholdPercentage;
    uint8 public interestRate;
    uint256 lastAccrued = block.timestamp;

    mapping(address => uint256) public userSupplyShares;
    // @TODO: Remove PositionParams from mapping and the rest of the code
    mapping(address => mapping(address => PositionParams)) public userPositions;

    constructor(
        IERC20 _loanToken,
        IERC20 _collateralToken,
        AggregatorV2V3Interface _loanTokenUsdPriceFeed,
        AggregatorV2V3Interface _collateralTokenUsdPriceFeed,
        uint8 _liquidationThresholdPercentage,
        uint8 _interestRate,
        PositionType _positionType
    ) {
        owner = msg.sender;
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        loanTokenUsdDataFeed = _loanTokenUsdPriceFeed;
        collateralTokenUsdDataFeed = _collateralTokenUsdPriceFeed;
        liquidationThresholdPercentage = _liquidationThresholdPercentage;
        positionType = _positionType;
        interestRate = _interestRate;
        contractId = _getContractId();
    }

    modifier onlyActivePosition(address onBehalf) {
        if (!userPositions[msg.sender][onBehalf].isActive) revert NoActivePosition();
        _;
    }

    function _getContractId() public view returns (bytes32) {
        return keccak256(abi.encode(address(loanToken), address(collateralToken)));
    }

    // @TODO: Remove below fn
    function createPosition() public returns (address) {
        LendingPosition onBehalf = new LendingPosition();
        userPositions[msg.sender][address(onBehalf)] =
            PositionParams({collateralAmount: 0, borrowShares: 0, timestamp: block.timestamp, isActive: true});

        _updatePosition(address(onBehalf));
        return address(onBehalf);
    }

    // @TODO: Remove below fn
    function getPosition(address onBehalf)
        public
        view
        returns (uint256 collateralAmount, uint256 borrowShares, uint256 timestamp, bool isActive)
    {
        PositionParams storage position = userPositions[msg.sender][onBehalf];
        return (position.collateralAmount, position.borrowShares, position.timestamp, position.isActive);
    }

    // @TODO: Remove below fn
    function closePosition(address onBehalf) public onlyActivePosition(onBehalf) {
        PositionParams storage position = userPositions[msg.sender][onBehalf];
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

        emit EventLib.UserSupplyShare(address(this), msg.sender, userSupplyShares[msg.sender]);
        emit EventLib.Supply(address(this), msg.sender, userSupplyShares[msg.sender]);
    }

    function withdraw(uint256 shares) public {
        if (shares == 0) revert ZeroAmount();
        if (shares > userSupplyShares[msg.sender]) revert InsufficientShares();

        _accrueInterest();

        uint256 amount = (shares * totalSupplyAssets) / totalSupplyShares;
        if (amount > totalSupplyAssets) revert InsufficientLiquidity();

        totalSupplyAssets -= amount;
        totalSupplyShares -= shares;
        userSupplyShares[msg.sender] -= shares;

        IERC20(loanToken).transfer(msg.sender, amount);

        emit EventLib.UserSupplyShare(address(this), msg.sender, userSupplyShares[msg.sender]);
        emit EventLib.Withdraw(address(this), msg.sender, userSupplyShares[msg.sender]);
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);

        userPositions[msg.sender][onBehalf].collateralAmount += amount;

        _updatePosition(onBehalf);
        emit EventLib.SupplyCollateralByPosition(
            address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]
        );
    }

    function withdrawCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        if (amount > userPositions[msg.sender][onBehalf].collateralAmount) revert InsufficientCollateral();

        IERC20(collateralToken).transfer(msg.sender, amount);
        userPositions[msg.sender][onBehalf].collateralAmount -= amount;

        _isHealthy(onBehalf);
        _updatePosition(onBehalf);
        emit EventLib.WithdrawCollateralByPosition(
            address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]
        );
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

        emit EventLib.BorrowByPosition(address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]);
    }

    function repayByPosition(address onBehalf, uint256 shares) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        if (shares == 0 || totalBorrowShares == 0) revert InvalidAmount();

        uint256 amount = (shares * totalBorrowAssets) / totalBorrowShares;
        if (amount == 0) revert InvalidAmount();

        // Reduce borrow shares
        PositionParams storage position = userPositions[msg.sender][onBehalf];
        if (position.borrowShares < shares) revert InvalidAmount();

        position.borrowShares -= shares;
        totalBorrowShares -= shares;
        totalBorrowAssets -= amount;

        // Transfer funds from user
        IERC20(loanToken).transferFrom(msg.sender, address(this), shares);

        _updatePosition(onBehalf);
        emit EventLib.RepayByPosition(address(this), msg.sender, onBehalf, userPositions[msg.sender][onBehalf]);
    }

    function accrueInterest() public {
        _accrueInterest();
    }

    // @TODO: move to Position
    function _updatePosition(address onBehalf) internal {
        PositionParams memory position = userPositions[msg.sender][onBehalf];
        position.timestamp = block.timestamp;

        emit EventLib.UserPosition(
            address(this),
            msg.sender,
            onBehalf,
            position.collateralAmount,
            position.borrowShares,
            position.timestamp,
            position.isActive
        );
    }

    function _accrueInterest() internal {
        uint256 interestPerYear = totalBorrowAssets * interestRate / 100;
        uint256 elapsedTime = block.timestamp - lastAccrued;

        uint256 interest = (interestPerYear * elapsedTime) / 365 days;

        totalBorrowAssets += interest;
        totalSupplyAssets += interest;

        lastAccrued = block.timestamp;

        emit EventLib.AccrueInterest(address(this), interestRate, interest);
    }

    function _isHealthy(address onBehalf) internal view {
        uint256 borrowShares = userPositions[msg.sender][onBehalf].borrowShares;
        uint256 collateral = PriceConverterLib.getConversionRate(
            userPositions[msg.sender][onBehalf].collateralAmount, collateralTokenUsdDataFeed, loanTokenUsdDataFeed
        );

        uint256 borrowAmount = totalBorrowShares == 0 ? 0 : (borrowShares * totalBorrowAssets) / totalBorrowShares;
        // Ensure borrowed doesn't exceed collateral before subtraction
        if (borrowAmount > collateral) revert InsufficientCollateral();

        uint256 allowedBorrowAmount = (collateral - borrowAmount) * ltv / 100;
        if (borrowAmount > allowedBorrowAmount) revert InsufficientCollateral();
    }

    // flashloan
    function flashLoan(address token, uint256 amount, bytes calldata data) external {
        if (amount == 0) revert ZeroAmount();

        IERC20(token).transfer(msg.sender, amount);

        IFlashLoanCallback(msg.sender).onFlashLoan(token, amount, data);

        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}
