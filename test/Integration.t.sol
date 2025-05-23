// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {PriceConverterLib} from "../src/libraries/PriceConverterLib.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Position} from "../src/Position.sol";
import {Vault} from "../src/Vault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";

contract IntegrationTest is Test {
    MockERC20 public mockUSDC;
    MockERC20 public mockWBTC;
    MockV3Aggregator public usdcUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    MockUniswapRouter public mockUniswapRouter;
    LendingPool public lendingPool;
    LendingPoolFactory public lendingPoolFactory;
    PositionFactory public positionFactory;
    MockFactory public mockFactory;
    Vault public vault;

    uint8 liquidationThresholdPercentage = 80;
    uint8 interestRate = 5;
    PositionType positionType = PositionType.LONG;
    mapping(address => mapping(address => bool)) public positions;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Setup Factory
        mockUniswapRouter = new MockUniswapRouter();
        vault = new Vault(address(this));
        lendingPoolFactory = new LendingPoolFactory(address(mockUniswapRouter), address(vault));
        positionFactory = new PositionFactory();
        mockFactory = new MockFactory();

        // Setup WBTC - USDC lending pool
        address loanToken = mockFactory.createMockToken("usdc", "USDC", 6);
        address loanTokenAggregator = mockFactory.createMockAggregator("usdc", "USDC", 6, 1e6);
        address collateralToken = mockFactory.createMockToken("wbtc", "WBTC", 8);
        address collateralTokenAggregator = mockFactory.createMockAggregator("wbtc", "WBTC", 8, 100_000e8);
        mockUniswapRouter.setPriceFeed(loanToken, loanTokenAggregator);
        mockUniswapRouter.setPriceFeed(collateralToken, collateralTokenAggregator);
        vault.setToken(loanToken, true);
        vault.setToken(collateralToken, true);

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
        vault.setLendingPool(lendingPoolAddress, true);

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsdPriceFeed));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcUsdPriceFeed));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("Liquidation Threshold Percentage:", liquidationThresholdPercentage);
        console.log("Interest Rate Percentage:", interestRate);
        console.log("Position Type (0 = LONG, 1 = SHORT):", uint8(positionType));
        console.log(positions[alice][address(mockWBTC)]); // Should print true if position exists
        console.log("==============================================================");

        // Mint tokens and provide liquidity
        mockWBTC.mint(address(vault), 100e8); // 100 WBTC (8 decimals)
        mockUSDC.mint(address(this), 1_000_000e6); // 1,000,000 USDC (6 decimals)
        supplyLiquidity(150_000e6); // Provide 150,000 USDC liquidity

        // Allocate funds to users
        mockUSDC.mint(alice, 20_000e6); // Alice gets 20,000 USDC
        mockWBTC.mint(alice, 3e8); // Alice gets 3 WBTC

        mockUSDC.mint(bob, 20_000e6); // Bob gets 20,000 USDC
        mockWBTC.mint(bob, 2e8); // Bob gets 2 WBTC

        // Ensure Vault Exists
        assert(address(vault) != address(0));

        // Check if LendingPool is using the correct Vault
        assertEq(address(lendingPool.vault()), address(vault));
    }

    // function testVaultReuse() public {
    //     bytes32 poolId = keccak256(abi.encode(address(mockUSDC), address(mockWBTC)));

    //     // First Lending Pool
    //     address firstVault = lendingPoolFactory.vaults(poolId);
    //     assert(firstVault != address(0));

    //     address lendingPool2Address = lendingPoolFactory.createLendingPool(
    //         address(mockUSDC),
    //         address(mockWBTC),
    //         address(usdcUsdPriceFeed),
    //         address(wbtcUsdPriceFeed),
    //         liquidationThresholdPercentage,
    //         interestRate,
    //         positionType
    //     );
    //     LendingPool lendingPool2 = LendingPool(lendingPool2Address);

    //     // Ensure Vault is Reused
    //     address secondVault = lendingPoolFactory.vaults(poolId);
    //     assertEq(firstVault, secondVault);
    // }

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
        Position position = new Position(address(lendingPool), user);
        address positionAddr = address(position);
        positions[alice][positionAddr] = true;
        lendingPool.registerPosition(positionAddr);
        console.log("Position created at", address(positionAddr));

        address creator = address(this);
        vm.startPrank(creator); // Ensure it's the creator making the call

        IERC20(mockWBTC).approve(positionAddr, _baseCollateral);
        position.openPosition(_baseCollateral, _leverage);
        vm.stopPrank();

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
        console.log("Position creator", position.creator());
        console.log("Position owner", position.owner());
        console.log("==============================================================");

        return positionAddr;
    }

    function test_createPosition() public {
        uint256 baseCollateral = 1e5; // 1 WBTC (8 decimals)
        uint8 leverage = 200;

        console.log("Before Alice create position");
        console.log("totalCollateral =", lendingPool.totalCollateral());
        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets =", lendingPool.totalBorrowAssets());
        console.log("vault balance WBTC =", MockERC20(mockWBTC).balanceOf(address(vault)));
        console.log("vault balance USDC =", MockERC20(mockUSDC).balanceOf(address(vault)));
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
        uint256 supplyCollateralAmount = 1e5;
        address randomOnBehalf = address(0x1234567890123456789012345678901234567890);

        vm.expectRevert(LendingPool.NoActivePosition.selector);
        lendingPool.supplyCollateralByPosition(randomOnBehalf, supplyCollateralAmount);
    }

    function test_addCollateral() public {
        uint256 baseCollateral = 1e5;
        uint8 leverage = 200;
        uint256 addedCollateral = 5e4;

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

        vm.startPrank(alice); // Ensure it's the creator
        IERC20(mockWBTC).approve(onBehalf, addedCollateral);
        IPosition(onBehalf).addCollateral(addedCollateral);
        vm.stopPrank();

        console.log("==============================================================");
        console.log("After Alice add collateral");
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());
    }

    function test_closePosition() public {
        uint256 baseCollateral = 1e5;
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

    function test_liquidatePosition() public {
        uint256 baseCollateral = 1e5;
        uint8 leverage = 200;

        address onBehalf = createPosition(alice, baseCollateral, leverage);
        Position position = Position(onBehalf);

        assertTrue(positions[alice][onBehalf], "Position is registered");

        console.log("Before crash: health =", position.health());
        console.log("Before crash: ltv =", position.ltv());

        // 🔻 Simulate market crash
        wbtcUsdPriceFeed.updateAnswer(10_000e8);

        // Update risk
        position.setRiskInfo();

        console.log("After crash: health =", position.health());
        console.log("After crash: ltv =", position.ltv());

        // ✅ Liquidate
        uint256 withdrawAmount = position.liquidatePosition();
        positions[alice][onBehalf] = false;

        console.log("Liquidated. Withdraw USDC:", withdrawAmount);
    }

    function test_repayPartial() public {
        uint256 baseCollateral = 1e5;
        uint8 leverage = 200;

        // Alice creates a leveraged position
        address onBehalf = createPosition(alice, baseCollateral, leverage);

        // Get how much she borrowed
        uint256 borrowBefore = IPosition(onBehalf).convertBorrowSharesToAmount(IPosition(onBehalf).borrowShares());
        console.log("Total Borrowed Amount:", borrowBefore);

        // Mint USDC to Alice for repayment
        uint256 repayAmount = borrowBefore / 2;
        mockUSDC.mint(alice, repayAmount);

        // Alice repays half
        vm.startPrank(alice);
        IERC20(mockUSDC).approve(onBehalf, repayAmount);
        IPosition(onBehalf).repay(repayAmount);
        vm.stopPrank();

        // Assert borrowShares reduced
        uint256 borrowAfter = IPosition(onBehalf).convertBorrowSharesToAmount(IPosition(onBehalf).borrowShares());
        console.log("Remaining Borrow Amount:", borrowAfter);
        assertLt(borrowAfter, borrowBefore, "Borrow amount should decrease after repayment");
    }

    function test_repayAll() public {
        uint256 baseCollateral = 1e5;
        uint8 leverage = 200;

        address onBehalf = createPosition(alice, baseCollateral, leverage);

        uint256 totalBorrowed = IPosition(onBehalf).convertBorrowSharesToAmount(IPosition(onBehalf).borrowShares());

        // Mint USDC to Alice
        mockUSDC.mint(alice, totalBorrowed);

        vm.startPrank(alice);
        IERC20(mockUSDC).approve(onBehalf, totalBorrowed);
        IPosition(onBehalf).repay(totalBorrowed);
        vm.stopPrank();

        assertEq(IPosition(onBehalf).borrowShares(), 0, "All borrow shares should be repaid");
    }
}
