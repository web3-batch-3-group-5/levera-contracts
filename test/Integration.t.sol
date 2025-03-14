// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {PriceConverterLib} from "../src/libraries/PriceConverterLib.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Position} from "../src/Position.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";

contract IntegrationTest is Test {
    MockERC20 public mockUSDC;
    MockERC20 public mockWBTC;
    MockV3Aggregator public usdcUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    LendingPool public lendingPool;
    LendingPoolFactory public lendingPoolFactory;
    PositionFactory public positionFactory;
    MockFactory public mockFactory;

    uint8 liquidationThresholdPercentage = 80;
    uint8 interestRate = 5;
    PositionType positionType = PositionType.LONG;
    mapping(address => mapping(address => bool)) public positions;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Setup Factory
        MockUniswapRouter mockUniswapRouter = new MockUniswapRouter();
        lendingPoolFactory = new LendingPoolFactory(address(mockUniswapRouter));
        positionFactory = new PositionFactory();
        mockFactory = new MockFactory();

        // Setup WBTC - USDC lending pool
        address loanToken = mockFactory.createMockToken("usdc", "USDC", 18);
        address loanTokenAggregator = mockFactory.createMockAggregator("usdc", "USDC", 18, 1e18);
        address collateralToken = mockFactory.createMockToken("wbtc", "WBTC", 18);
        address collateralTokenAggregator = mockFactory.createMockAggregator("wbtc", "WBTC", 18, 100_000e18);
        mockUniswapRouter.setPriceFeed(loanToken, loanTokenAggregator);
        mockUniswapRouter.setPriceFeed(collateralToken, collateralTokenAggregator);

        mockUSDC = MockERC20(loanToken);
        mockWBTC = MockERC20(collateralToken);
        usdcUsdPriceFeed = MockV3Aggregator(loanTokenAggregator);
        wbtcUsdPriceFeed = MockV3Aggregator(collateralTokenAggregator);
        address lendingPoolAddress = lendingPoolFactory.createLendingPool(
            address(mockUSDC),
            address(mockWBTC),
            address(usdcUsdPriceFeed),
            address(wbtcUsdPriceFeed),
            liquidationThresholdPercentage,
            interestRate,
            positionType
        );
        lendingPool = LendingPool(lendingPoolAddress);

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsdPriceFeed));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcUsdPriceFeed));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("Liquidation Threshold Percentage:", liquidationThresholdPercentage);
        console.log("Interest Rate Percentage:", interestRate);
        console.log("Position Type (0 = LONG, 1 = SHORT):", uint8(positionType));
        console.log("==============================================================");

        mockWBTC.mint(address(lendingPool), 1_000_000e18);
        mockUSDC.mint(address(this), 1_000_000e18);
        supplyLiquidity(1500e18);

        mockUSDC.mint(alice, 2_000e18);
        mockWBTC.mint(alice, 3e18);
        // Alice supply liquidity
        // vm.startPrank(alice);
        // supplyLiquidity(50_000e18);
        // vm.stopPrank();

        mockUSDC.mint(bob, 2_000e18);
        mockWBTC.mint(bob, 2e18);
        // Bob supply liquidity
        // vm.startPrank(bob);
        // supplyLiquidity(50_000e18);
        // vm.stopPrank();
    }

    function supplyLiquidity(uint256 amount) internal {
        IERC20(mockUSDC).approve(address(lendingPool), amount);
        lendingPool.supply(amount);
    }

    function createPosition(address user, uint256 _baseCollateral, uint8 _leverage)
        private
        returns (address onBehalf)
    {
        vm.startPrank(user);
        IERC20(mockWBTC).approve(address(this), _baseCollateral);
        IERC20(mockWBTC).transfer(address(this), _baseCollateral);
        vm.stopPrank();

        // Treat IntegrationTest as PositionFactory
        Position position = new Position(address(lendingPool), lendingPool.router(), user);
        address positionAddr = address(position);
        positions[alice][positionAddr] = true;
        lendingPool.registerPosition(positionAddr);
        console.log("Position created at", address(positionAddr));

        IERC20(mockWBTC).approve(positionAddr, _baseCollateral);

        position.openPosition(_baseCollateral, _leverage);

        console.log("======================== Position ===========================");
        console.log("Before Alice create position");
        console.log("Base Collateral", position.baseCollateral());
        console.log("Effective Collateral", position.effectiveCollateral());
        console.log("Leverage", position.leverage());
        console.log("Liquidation Price", position.liquidationPrice());
        console.log("Health", position.health());
        console.log("LTV", position.ltv());
        console.log("Borrow Shares", position.borrowShares());
        console.log("Estimated Borrow Amount", position.convertBorrowSharesToAmount(position.borrowShares()));
        console.log("==============================================================");

        return positionAddr;
    }

    function test_createPosition() public {
        uint256 baseCollateral = 1e12;
        uint8 leverage = 200;

        console.log("Before Alice create position");
        console.log("totalCollateral =", lendingPool.totalCollateral());
        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets =", lendingPool.totalBorrowAssets());
        console.log("==============================================================");

        // Alice Create Position
        address onBehalf = createPosition(alice, baseCollateral, leverage);

        assertTrue(positions[alice][onBehalf], "Position is registered in Position Factory");
        assertEq(
            IPosition(onBehalf).effectiveCollateral(),
            baseCollateral * leverage / 100,
            "Effective Collateral should be equal to Base Collateral multiplied by Leverage"
        );

        console.log("==============================================================");
        console.log("After Alice create position");
        console.log("totalCollateral =", lendingPool.totalCollateral());
        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets =", lendingPool.totalBorrowAssets());
    }

    function test_supplyCollateralByPosition_NoActivePosition() public {
        uint256 supplyCollateralAmount = 100_000e18;
        address randomOnBehalf = address(0x1234567890123456789012345678901234567890);

        vm.expectRevert(LendingPool.NoActivePosition.selector);
        lendingPool.supplyCollateralByPosition(randomOnBehalf, supplyCollateralAmount);
    }

    function test_addCollateral() public {
        uint256 baseCollateral = 1e12;
        uint8 leverage = 200;
        uint256 addedCollateral = 5e11;

        // Alice Create Position
        address onBehalf = createPosition(alice, baseCollateral, leverage);

        assertTrue(positions[alice][onBehalf], "Position is registered in Position Factory");
        console.log("==============================================================");
        console.log("After Alice create position");
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());

        vm.startPrank(alice);
        IERC20(mockWBTC).approve(address(this), addedCollateral);
        IERC20(mockWBTC).transfer(address(this), addedCollateral);
        vm.stopPrank();

        IERC20(mockWBTC).approve(onBehalf, addedCollateral);
        IPosition(onBehalf).addCollateral(addedCollateral);

        console.log("==============================================================");
        console.log("After Alice add collateral");
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());
    }

    function test_closePosition() public {
        uint256 baseCollateral = 1e12;
        uint8 leverage = 200;

        // Alice Create Position
        address onBehalf = createPosition(alice, baseCollateral, leverage);

        assertTrue(positions[alice][onBehalf], "Position is registered in Position Factory");
        console.log("==============================================================");
        console.log("After Alice create position");
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());

        uint256 withdrawAmount = IPosition(onBehalf).closePosition();
        positions[alice][onBehalf] = false;

        console.log("==============================================================");
        console.log("After Alice close position");
        console.log("mockUSDC balance token", IERC20(mockUSDC).balanceOf(address(this)));
        console.log("withdrawAmount =", withdrawAmount);
    }
}
