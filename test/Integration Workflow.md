#Create LendingPool

- Using LendingPoolFactory
  fn createLendingPool({
  address loanToken,
  address collateralToken,
  address loanTokenUsdPriceFeed,
  address collateralTokenUsdPriceFeed,
  uint8 liquidationTresholdPercentage, // defined by pool creator
  enum positionType, // defined by pool creator
  uint8 interestRate // defined by pool creator
  }) returns(bool status)

#Create Position

- fn createPosition({ address lendingPool, unit256 collateral, uint8 leverage }) returns(bool status)
  Using PositionFactory

  - Create Position contract
    address positionAddress = new Position(...)

  - Calculate borrowCollateralPrice
    totalCollateral = collateral x leverage;
    borrowCollateral = initialCollateral x (leverage - 1);

    uint totalCollateralPrice = lendingPool.convertCollateral(totalCollateral);
    uint borrowCollateralPrice = lendingPool.convertCollateral(borrowCollateral);

    ```
    fn convertCollateral(unit256 collateral) returns(uint256 amount)
      PriceConverterLib.getConversionRate(collateral, collateralTokenUsdDataFeed, loanTokenUsdDataFeed)
    ```

  - Calculate LP, LTV and health
    lendingPool.getLiquidationPrice(uint256 totalCollateral, uint256 borrowAmount) returns(uint8 liquidationPrice)
    lendingPool.getHealth(uint256 totalCollateralPrice, uint256 borrowAmount) returns(uint8 health)
    lendingPool.getLTV(uint256 totalCollateralPrice, uint256 borrowAmount) returns(uint8 ltv)

  Using Position

  - fn addLeverage(unit256 initialCollateral, unit256 borrowAmount)

    - Add collateral on FlashLoan
      lendingPool.flashloan(loanToken, borrowAmount)

    - Calculate borrowShare
      lendingPool.convertBorrowAssetToShare(uint256 borrowAmount) returns(unit256 borrowShare)

  - Emit subgraph
    emitPosition(
    address lendingPool,
    address msg.sender,
    address positionAddress,
    address loanToken,
    address collateralToken,
    unit256 collateral,
    unit256 borrowShare,
    uint8 leverage,
    uint8 liquidationPrice,
    uint8 health
    uint8 ltv)

- fn getPosition({ address lendingPool, address msg.sender })
  Using Subgraph

- fn changeLeverage({ address lendingPool, address positionAddress, uint8 collateral, uint8 leverage }) returns(bool status)
  Using Position

  - Calculate the difference
    newTotalCollateral = collateral x leverage;

    - if (newTotalColateral < currTotalColateral)
      diffTotalColateral = currTotalColateral - newTotalColateral
