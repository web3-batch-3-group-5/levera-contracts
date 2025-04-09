// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Position} from "../src/Position.sol";
import {Vault} from "../src/Vault.sol";

/*
 * We cannot debug unverified contract hence it's important to create REPL file for setup
 */
contract REPLDeploy is Script {
    struct LendingPoolConfig {
        address loanToken;
        address collateralToken;
        address loanTokenPriceFeed;
        address collateralTokenPriceFeed;
        uint256 supplyAmount;
    }

    address MOCK_UNISWAP_ROUTER;
    address MOCK_VAULT;
    address POSITION_FACTORY;
    address LENDING_POOL_FACTORY;
    address LA_DAI;
    address LA_DAI_PRICE_FEED;
    address LA_USDC;
    address LA_USDC_PRICE_FEED;
    address LA_USDT;
    address LA_USDT_PRICE_FEED;
    address LA_WBTC;
    address LA_WBTC_PRICE_FEED;
    address LA_WETH;
    address LA_WETH_PRICE_FEED;

    LendingPoolConfig[] private lendingPoolSeeds;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory fullPath = string.concat(root, "/config.json");
        string memory json = vm.readFile(fullPath);
        string memory chain = "eduChainTestnet";

        MOCK_UNISWAP_ROUTER = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_UNISWAP_ROUTER"));
        POSITION_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".POSITION_FACTORY"));
        LENDING_POOL_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".LENDING_POOL_FACTORY"));
        MOCK_VAULT = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_VAULT"));
        LA_DAI = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_DAI"));
        LA_DAI_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_DAI_PRICE_FEED"));
        LA_USDC = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDC"));
        LA_USDC_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDC_PRICE_FEED"));
        LA_USDT = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDT"));
        LA_USDT_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDT_PRICE_FEED"));
        LA_WBTC = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WBTC"));
        LA_WBTC_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WBTC_PRICE_FEED"));
        LA_WETH = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WETH"));
        LA_WETH_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WETH_PRICE_FEED"));
    }

    function _mintMockToken() public {
        address receiver = 0x6dE5361925d8f869fA7dEECe6cF842CC703fE26f;
        MockERC20(LA_USDC).mint(receiver, 1_000_000e6);
        MockERC20(LA_WBTC).mint(receiver, 1_000e8);

        console.log("Balance LaUSDC", MockERC20(LA_USDC).balanceOf(receiver));
        console.log("Balance LaWBTC", MockERC20(LA_WBTC).balanceOf(receiver));
    }

    function _supplyLendingPool(address lendingPoolAddr) internal {
        uint256 supplyAmount = 1000e6; // LaUSDC
        uint256 collateralReserve = 10_000e8; // LaWBTC -- need deposit for flashloan

        address loanToken = ILendingPool(lendingPoolAddr).loanToken();
        address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();

        MockERC20(collateralToken).mint(address(this), collateralReserve);
        MockERC20(loanToken).mint(address(this), supplyAmount);
        MockERC20(collateralToken).mint(lendingPoolAddr, collateralReserve);
        MockERC20(loanToken).approve(lendingPoolAddr, supplyAmount);
        ILendingPool(lendingPoolAddr).supply(supplyAmount);
    }

    function _init() internal {
        uint256 baseCollateral = 1e2; // LaWBTC
        uint256 leverage = 200;

        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));
        _mintMockToken();

        // Create Lending Pool
        address lendingPoolAddr = 0x650E2823E16B0FCea6dB27798286AB36bbbf9347;
        // LendingPoolFactory lendingPoolFactory = LendingPoolFactory(LENDING_POOL_FACTORY);
        // address lendingPoolAddr = lendingPoolFactory.createLendingPool(
        //     LA_USDC, LA_WBTC, LA_USDC_PRICE_FEED, LA_WBTC_PRICE_FEED, 80, 5, PositionType.LONG
        // );
        // console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));

        // Supply Lending Pool for flashloan
        // _supplyLendingPool(lendingPoolAddr);

        console.log("Lending Pool deployed at:", lendingPoolAddr);
        address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();

        // Create Position
        PositionFactory positionFactory = PositionFactory(POSITION_FACTORY);
        MockERC20(collateralToken).approve(address(this), baseCollateral);
        MockERC20(collateralToken).approve(address(positionFactory), baseCollateral);
        console.log("Position Factory deployed at:", address(positionFactory));

        address onBehalf = positionFactory.createPosition(lendingPoolAddr, baseCollateral, leverage);
        console.log("Position deployed at:", onBehalf);

        // Destroy
        positionFactory.deletePosition(lendingPoolAddr, onBehalf);
        // lendingPoolFactory.discardLendingPool(lendingPoolAddr);
        vm.stopBroadcast();
    }

    function _createBulkLendingPools() internal {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        LendingPoolFactory lendingPoolFactory = LendingPoolFactory(LENDING_POOL_FACTORY);
        Vault vault = Vault(MOCK_VAULT);

        lendingPoolSeeds.push(LendingPoolConfig(LA_USDC, LA_WBTC, LA_USDC_PRICE_FEED, LA_WBTC_PRICE_FEED, 10_000e6));
        lendingPoolSeeds.push(LendingPoolConfig(LA_USDC, LA_WETH, LA_USDC_PRICE_FEED, LA_WETH_PRICE_FEED, 10_000e6));
        lendingPoolSeeds.push(LendingPoolConfig(LA_USDT, LA_WBTC, LA_USDT_PRICE_FEED, LA_WBTC_PRICE_FEED, 10_000e6));
        lendingPoolSeeds.push(LendingPoolConfig(LA_USDT, LA_WETH, LA_USDT_PRICE_FEED, LA_WETH_PRICE_FEED, 10_000e6));
        lendingPoolSeeds.push(LendingPoolConfig(LA_DAI, LA_WBTC, LA_DAI_PRICE_FEED, LA_WBTC_PRICE_FEED, 10_000e18));
        lendingPoolSeeds.push(LendingPoolConfig(LA_DAI, LA_WETH, LA_DAI_PRICE_FEED, LA_WETH_PRICE_FEED, 10_000e18));

        for (uint256 i = 0; i < lendingPoolSeeds.length; i++) {
            LendingPoolConfig memory lendingPool = lendingPoolSeeds[i];
            address lendingPoolAddr = lendingPoolFactory.createLendingPool(
                lendingPool.loanToken,
                lendingPool.collateralToken,
                lendingPool.loanTokenPriceFeed,
                lendingPool.collateralTokenPriceFeed,
                80,
                5,
                PositionType.LONG
            );
            console.log("Lending Pool deployed at:", lendingPoolAddr);

            address loanToken = ILendingPool(lendingPoolAddr).loanToken();
            address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();

            vault.setLendingPool(lendingPoolAddr, true);
            vault.setToken(loanToken, true);
            vault.setToken(collateralToken, true);

            MockERC20(loanToken).approve(lendingPoolAddr, lendingPool.supplyAmount);
            ILendingPool(lendingPoolAddr).supply(lendingPool.supplyAmount);
        }

        vm.stopBroadcast();
    }

    function run() external {
        _init();
    }
}
