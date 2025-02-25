// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";
import {EventLib} from "./libraries/EventLib.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {PositionType, ISwapRouter} from "./interfaces/ILendingPool.sol";

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

    address public router;
    address public immutable owner;
    address public immutable creator;
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
    uint256 public totalCollateral;
    uint256 public ltp; // Liquidation Threshold Percentage
    uint256 public interestRate;
    uint256 lastAccrued = block.timestamp;

    mapping(address => bool) public userPositions;
    mapping(address => uint256) public userSupplyShares;

    constructor(
        IERC20 _loanToken,
        IERC20 _collateralToken,
        AggregatorV2V3Interface _loanTokenUsdPriceFeed,
        AggregatorV2V3Interface _collateralTokenUsdPriceFeed,
        address _router,
        uint256 _ltp,
        uint256 _interestRate,
        PositionType _positionType,
        address _creator
    ) {
        owner = msg.sender;
        creator = _creator;
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        loanTokenUsdDataFeed = _loanTokenUsdPriceFeed;
        collateralTokenUsdDataFeed = _collateralTokenUsdPriceFeed;
        router = _router;
        ltp = _ltp;
        positionType = _positionType;
        interestRate = _interestRate;
        contractId = _getContractId();
    }

    modifier onlyActivePosition(address onBehalf) {
        if (!userPositions[onBehalf]) revert NoActivePosition();
        _;
    }

    function _getContractId() public view returns (bytes32) {
        return keccak256(abi.encode(address(loanToken), address(collateralToken)));
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
        IERC20(loanToken).approve(address(this), amount);
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

    function registerPosition(address onBehalf) public {
        userPositions[onBehalf] = true;
    }

    function unregisterPosition(address onBehalf) public {
        userPositions[onBehalf] = true;
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        totalCollateral += amount;
        IERC20(collateralToken).approve(address(this), amount);
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
    }

    function withdrawCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        totalCollateral -= amount;
        IERC20(collateralToken).transfer(msg.sender, amount);
    }

    function borrowByPosition(address onBehalf, uint256 amount)
        public
        onlyActivePosition(onBehalf)
        returns (uint256 shares)
    {
        uint256 availableLiquidity = IERC20(loanToken).balanceOf(address(this));
        if (availableLiquidity < amount) revert InsufficientLiquidity();

        _accrueInterest();

        if (totalBorrowAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalBorrowShares) / totalBorrowAssets;
        }

        totalBorrowAssets += amount;
        totalBorrowShares += shares;

        return shares;
    }

    function repayByPosition(address onBehalf, uint256 shares) public onlyActivePosition(onBehalf) {
        _accrueInterest();

        if (shares == 0 || totalBorrowShares == 0) revert InvalidAmount();

        uint256 amount = (shares * totalBorrowAssets) / totalBorrowShares;
        if (amount == 0) revert InvalidAmount();

        totalBorrowShares -= shares;
        totalBorrowAssets -= amount;

        IERC20(loanToken).approve(address(this), amount);
        IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
    }

    function accrueInterest() public {
        _accrueInterest();
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

    // flashloan
    function flashLoan(address token, uint256 amount, bytes calldata data) external {
        if (amount == 0) revert ZeroAmount();

        IERC20(token).transfer(msg.sender, amount);

        IFlashLoanCallback(msg.sender).onFlashLoan(token, amount, data);

        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function getLiquidationPrice(uint256 effectiveCollateral, uint256 borrowAmount) external view returns (uint256) {
        return uint256(borrowAmount * 100 / (effectiveCollateral * ltp));
    }

    function getHealth(uint256 effectiveCollateralPrice, uint256 borrowAmount) external view returns (uint256) {
        return uint256((effectiveCollateralPrice * ltp) / (borrowAmount * 100));
    }

    function getLTV(uint256 effectiveCollateralPrice, uint256 borrowAmount) external pure returns (uint256) {
        return uint256(borrowAmount / effectiveCollateralPrice);
    }

    function getUtilizationRate() external view returns (uint256) {
        if (totalBorrowAssets == 0) return 0;
        return totalSupplyAssets * 100 / totalBorrowAssets;
    }
}
