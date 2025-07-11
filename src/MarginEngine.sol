// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {ISwapRouter} from "./interfaces/IVault.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";

contract MarginEngine is Ownable {
    struct TokenInfo {
        address chainlinkFeed;
        address token;
        uint8 decimals;
        bool isActive;
        uint256 manualPrice;
        uint256 manualPriceTimestamp;
        bool useManualPrice;
    }

    struct PriceData {
        uint256 oraclePrice;
        uint256 uniswapPrice;
        uint256 oracleTimestamp;
        uint256 deviation;
        bool isOracleStale;
    }

    mapping(string => TokenInfo) public tokens;
    mapping(address => string) public tokenToSymbol;

    IQuoter public immutable quoter;
    ISwapRouter public immutable swapRouter;

    uint256 public stalePriceThreshold = 3600; // 1 hour in seconds
    uint256 public maxPriceDeviation = 500; // 5% in basis points (500/10000)
    uint24 public defaultPoolFee = 500; // 0.05%

    event TokenAdded(string indexed symbol, address indexed token, address indexed chainlinkFeed);
    event PriceDeviation(string indexed symbol, uint256 oraclePrice, uint256 uniswapPrice, uint256 deviation);
    event StalePriceDetected(string indexed symbol, uint256 lastUpdate, uint256 threshold);
    event ManualPriceSet(string indexed symbol, uint256 price, uint256 timestamp);

    constructor(address _quoter, address _swapRouter) Ownable(msg.sender) {
        quoter = IQuoter(_quoter);
        swapRouter = ISwapRouter(_swapRouter);
    }

    /// @notice Admin function to register new tokens
    function addToken(string memory symbol, address token, address chainlinkFeed, uint8 decimals)
        public
        virtual
        onlyOwner
    {
        require(token != address(0), "Invalid token address");
        require(chainlinkFeed != address(0), "Invalid chainlink feed");
        require(bytes(symbol).length > 0, "Invalid symbol");

        tokens[symbol] = TokenInfo({
            chainlinkFeed: chainlinkFeed,
            token: token,
            decimals: decimals,
            isActive: true,
            manualPrice: 0,
            manualPriceTimestamp: 0,
            useManualPrice: false
        });

        tokenToSymbol[token] = symbol;
        emit TokenAdded(symbol, token, chainlinkFeed);
    }

    /// @notice Toggle token active status
    function setTokenActive(string memory symbol, bool active) external onlyOwner {
        require(tokens[symbol].token != address(0), "Token not found");
        tokens[symbol].isActive = active;
    }

    /// @notice Set staleness threshold for oracle prices
    function setStalePriceThreshold(uint256 seconds_) external onlyOwner {
        stalePriceThreshold = seconds_;
    }

    /// @notice Set maximum acceptable price deviation between oracle and DEX
    function setMaxPriceDeviation(uint256 basisPoints) external onlyOwner {
        require(basisPoints <= 5000, "Deviation too high"); // Max 50%
        maxPriceDeviation = basisPoints;
    }

    /// @notice Set default pool fee for Uniswap queries
    function setDefaultPoolFee(uint24 fee) external onlyOwner {
        defaultPoolFee = fee;
    }

    /// @notice Set manual price for a token (used when oracle is stale)
    function setPrice(string memory symbol, uint256 price) external onlyOwner {
        require(tokens[symbol].token != address(0), "Token not found");
        require(price > 0, "Price must be positive");

        tokens[symbol].manualPrice = price;
        tokens[symbol].manualPriceTimestamp = block.timestamp;
        tokens[symbol].useManualPrice = true;

        emit ManualPriceSet(symbol, price, block.timestamp);
    }

    /// @notice Disable manual price and return to oracle price
    function disableManualPrice(string memory symbol) external onlyOwner {
        require(tokens[symbol].token != address(0), "Token not found");

        tokens[symbol].useManualPrice = false;
        tokens[symbol].manualPrice = 0;
        tokens[symbol].manualPriceTimestamp = 0;
    }

    /// @notice Auto-set price when oracle is stale (emergency function)
    function autoSetPriceOnStale(string memory symbol) external onlyOwner {
        (uint256 currentPrice,, bool isStale) = getOraclePriceView(symbol);

        if (isStale) {
            // Use the last known oracle price as manual price
            tokens[symbol].manualPrice = currentPrice;
            tokens[symbol].manualPriceTimestamp = block.timestamp;
            tokens[symbol].useManualPrice = true;

            emit ManualPriceSet(symbol, currentPrice, block.timestamp);
        } else {
            revert("Oracle price is not stale");
        }
    }

    /// @notice Get oracle price (view function - safe for frontend)
    function getOraclePriceView(string memory symbol)
        public
        view
        virtual
        returns (uint256 price, uint256 updatedAt, bool isStale)
    {
        TokenInfo memory info = tokens[symbol];
        require(info.token != address(0), "Token not supported");
        require(info.isActive, "Token inactive");

        // Check if manual price is set and should be used
        if (info.useManualPrice && info.manualPriceTimestamp > 0) {
            price = info.manualPrice;
            updatedAt = info.manualPriceTimestamp;
            isStale = block.timestamp - info.manualPriceTimestamp > stalePriceThreshold;
            return (price, updatedAt, isStale);
        }

        AggregatorV2V3Interface feed = AggregatorV2V3Interface(info.chainlinkFeed);
        (, int256 rawPrice,, uint256 timeStamp,) = feed.latestRoundData();

        require(rawPrice > 0, "Invalid oracle price");

        isStale = timeStamp == 0 || block.timestamp - timeStamp > stalePriceThreshold;

        // Normalize to 18 decimals
        price = uint256(rawPrice) * 1e18 / (10 ** feed.decimals());
        updatedAt = timeStamp;
    }

    /// @notice Get oracle price (can emit events - for internal use)
    function getOraclePrice(string memory symbol)
        public
        virtual
        returns (uint256 price, uint256 updatedAt, bool isStale)
    {
        (price, updatedAt, isStale) = getOraclePriceView(symbol);

        // Emit event if price is stale
        if (isStale) {
            emit StalePriceDetected(symbol, updatedAt, stalePriceThreshold);
        }
    }

    /// @notice Get Uniswap price (for actual swaps)
    function getUniswapPrice(string memory symbolIn, string memory symbolOut, uint256 amountIn, uint24 fee)
        public
        returns (uint256 amountOut)
    {
        TokenInfo memory from = tokens[symbolIn];
        TokenInfo memory to = tokens[symbolOut];

        require(from.token != address(0) && to.token != address(0), "Invalid tokens");
        require(from.isActive && to.isActive, "Token inactive");

        if (fee == 0) fee = defaultPoolFee;

        try quoter.quoteExactInputSingle(from.token, to.token, fee, amountIn, 0) returns (uint256 quote) {
            amountOut = quote;
        } catch {
            // Fallback to oracle price if Uniswap fails
            amountOut = getOracleConversionRate(symbolIn, symbolOut, amountIn);
        }
    }

    /// @notice Get oracle-based conversion rate (fallback for Uniswap failures)
    function getOracleConversionRate(string memory symbolIn, string memory symbolOut, uint256 amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        TokenInfo memory from = tokens[symbolIn];
        TokenInfo memory to = tokens[symbolOut];

        require(from.token != address(0) && to.token != address(0), "Invalid tokens");

        return PriceConverterLib.getConversionRate(
            amountIn, AggregatorV2V3Interface(from.chainlinkFeed), AggregatorV2V3Interface(to.chainlinkFeed)
        );
    }

    /// @notice Get comprehensive price data for a token pair
    function getPriceData(string memory symbolIn, string memory symbolOut, uint256 amountIn, uint24 fee)
        external
        returns (PriceData memory data)
    {
        // Get oracle prices
        (, uint256 timestampIn, bool isStaleIn) = getOraclePriceView(symbolIn);
        (, uint256 timestampOut, bool isStaleOut) = getOraclePriceView(symbolOut);

        // Calculate oracle-based conversion
        uint256 oracleAmountOut = getOracleConversionRate(symbolIn, symbolOut, amountIn);

        // Get Uniswap price
        uint256 uniswapAmountOut = getUniswapPrice(symbolIn, symbolOut, amountIn, fee);

        // Calculate deviation
        uint256 deviation = 0;
        if (oracleAmountOut > 0) {
            uint256 diff = oracleAmountOut > uniswapAmountOut
                ? oracleAmountOut - uniswapAmountOut
                : uniswapAmountOut - oracleAmountOut;
            deviation = (diff * 10000) / oracleAmountOut; // basis points
        }

        // Check if deviation exceeds threshold
        if (deviation > maxPriceDeviation) {
            emit PriceDeviation(symbolIn, oracleAmountOut, uniswapAmountOut, deviation);
        }

        data = PriceData({
            oraclePrice: oracleAmountOut,
            uniswapPrice: uniswapAmountOut,
            oracleTimestamp: timestampIn < timestampOut ? timestampIn : timestampOut,
            deviation: deviation,
            isOracleStale: isStaleIn || isStaleOut
        });
    }

    /// @notice Execute actual swap using the swap router
    function executeSwap(
        string memory symbolIn,
        string memory symbolOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint24 fee,
        address recipient
    ) external returns (uint256 amountOut) {
        TokenInfo memory from = tokens[symbolIn];
        TokenInfo memory to = tokens[symbolOut];

        require(from.token != address(0) && to.token != address(0), "Invalid tokens");
        require(from.isActive && to.isActive, "Token inactive");

        if (fee == 0) fee = defaultPoolFee;

        // Transfer tokens from sender
        IERC20(from.token).transferFrom(msg.sender, address(this), amountIn);
        IERC20(from.token).approve(address(swapRouter), amountIn);

        // Execute swap
        amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: from.token,
                tokenOut: to.token,
                fee: fee,
                recipient: recipient,
                deadline: block.timestamp + 300, // 5 minutes
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /// @notice Preview swap without executing (for frontend display)
    function previewSwap(string memory symbolIn, string memory symbolOut, uint256 amountIn, uint24 fee, bool useOracle)
        external
        returns (uint256 amountOut)
    {
        if (useOracle) {
            // Use oracle price for display
            amountOut = getOracleConversionRate(symbolIn, symbolOut, amountIn);
        } else {
            // Use real Uniswap price
            amountOut = getUniswapPrice(symbolIn, symbolOut, amountIn, fee);
        }
    }

    /// @notice Calculate position requirements based on oracle price
    function calculatePositionRequirements(
        string memory collateralSymbol,
        string memory borrowSymbol,
        uint256 collateralAmount,
        uint256 leverage
    ) external view returns (uint256 borrowAmount, uint256 liquidationPrice, uint256 healthFactor) {
        require(leverage >= 100, "Leverage must be >= 100");

        // Use oracle prices for position calculations
        (uint256 collateralPrice,, bool isStale) = getOraclePriceView(collateralSymbol);
        (uint256 borrowPrice,, bool isStaleB) = getOraclePriceView(borrowSymbol);

        require(!isStale && !isStaleB, "Stale oracle price");

        uint256 collateralValueUSD = (collateralAmount * collateralPrice) / 1e18;
        uint256 borrowValueUSD = (collateralValueUSD * (leverage - 100)) / 100;

        borrowAmount = (borrowValueUSD * 1e18) / borrowPrice;

        // Simplified liquidation price calculation (80% LTV)
        liquidationPrice = (borrowValueUSD * 1e18) / (collateralAmount * 80 / 100);

        // Health factor calculation
        healthFactor = (collateralValueUSD * 80) / (borrowValueUSD * 100);
    }

    /// @notice Get token info by symbol
    function getTokenInfo(string memory symbol) external view returns (TokenInfo memory) {
        return tokens[symbol];
    }

    /// @notice Get symbol by token address
    function getSymbolByToken(address token) external view returns (string memory) {
        return tokenToSymbol[token];
    }

    /// @notice Check if token is supported and active
    function isTokenSupported(string memory symbol) external view returns (bool) {
        return tokens[symbol].token != address(0) && tokens[symbol].isActive;
    }

    /// @notice Get multiple token prices at once (for frontend efficiency)
    function getMultipleOraclePrices(string[] memory symbols)
        external
        view
        returns (uint256[] memory prices, uint256[] memory timestamps, bool[] memory isStale)
    {
        prices = new uint256[](symbols.length);
        timestamps = new uint256[](symbols.length);
        isStale = new bool[](symbols.length);

        for (uint256 i = 0; i < symbols.length; i++) {
            (prices[i], timestamps[i], isStale[i]) = getOraclePriceView(symbols[i]);
        }
    }
}
