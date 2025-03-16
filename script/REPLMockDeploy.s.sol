// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";

/*
 * We cannot interact with Flame Block Explorer hence it's important to create REPL file for setup
 * 1) Create MockAggregator and pair token - aggregator
 * 2) Minting
 */
contract REPLMockDeploy is Script {
    struct MockConfig {
        address contractAddr;
        string name;
        string symbol;
        uint8 decimals;
        int256 price;
    }

    address MOCK_UNISWAP_ROUTER;
    address MOCK_FACTORY;
    address LA_DAI;
    address LA_USDC;
    address LA_USDT;
    address LA_WBTC;
    address LA_WETH;

    MockConfig[] private mockTokens;

    constructor() {}

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory fullPath = string.concat(root, "/config.json");
        string memory json = vm.readFile(fullPath);
        string memory chain = "109695";

        MOCK_UNISWAP_ROUTER = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_UNISWAP_ROUTER"));
        MOCK_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_FACTORY"));
        LA_DAI = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_DAI"));
        LA_USDC = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDC"));
        LA_USDT = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDT"));
        LA_WBTC = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WBTC"));
        LA_WETH = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WETH"));

        mockTokens.push(MockConfig(LA_DAI, "Mock DAI", "laDAI", 18, 1e18));
        mockTokens.push(MockConfig(LA_USDC, "Mock USD Coin", "laUSDC", 6, 1e6));
        mockTokens.push(MockConfig(LA_USDT, "Mock USD Token", "laUSDT", 6, 1e6));
        mockTokens.push(MockConfig(LA_WBTC, "Mock Wrapped Bitcoin", "laWBTC", 8, 100_000e8));
        mockTokens.push(MockConfig(LA_WETH, "Mock Wrapped Ethereum", "laWETH", 18, 2_500e18));
    }

    function setupFlameMockUniswapRouter() public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        MockFactory mockFactory = MockFactory(MOCK_FACTORY);
        MockUniswapRouter mockUniswapRouter = MockUniswapRouter(MOCK_UNISWAP_ROUTER);

        console.log("================ Configure Mock in Router =================");
        console.log("Mock Uniswap Router deployed at:", MOCK_UNISWAP_ROUTER);
        for (uint256 i = 0; i < mockTokens.length; i++) {
            MockConfig memory token = mockTokens[i];
            mockFactory.storeMockToken(token.name, token.symbol, token.contractAddr);

            // // Discard if exist
            // mockFactory.discardMockAggregator(token.name, token.symbol);

            address priceFeed = mockFactory.createMockAggregator(token.name, token.symbol, token.decimals, token.price);
            // bytes32 id = keccak256(abi.encode(token.name, token.symbol));
            // address priceFeed = mockFactory.aggregators(id);

            mockUniswapRouter.setPriceFeed(token.contractAddr, priceFeed);
            console.log(string(abi.encodePacked("[", token.symbol, "] Aggregator: ")), priceFeed);
        }
        console.log("===========================================================");
        vm.stopBroadcast();
    }

    function mintMockToken() public {
        address receiver = 0x2808Dc7E5eFC9409CdD6166E01ce44Ae9a84bb32;
        for (uint256 i = 0; i < mockTokens.length; i++) {
            address token = mockTokens[i].contractAddr;
            MockERC20 mockERC20 = MockERC20(token);
            mockERC20.mint(receiver, 10 ** mockERC20.decimals());
            console.log(string(abi.encodePacked("Successfully mint ", mockTokens[i].symbol, " to Address:")), receiver);
        }
    }

    function run() external {
        mintMockToken();
    }
}
