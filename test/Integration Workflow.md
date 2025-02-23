# Create LendingPool

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
    address positionAddress = new Position(address lendingPool)

  - Calculate borrowCollateralPrice (borrow collateral price in USDC)
    initialCollateral = 20 ARB;
    totalCollateral = collateral x leverage; // 20 x 2 = 40
    borrowCollateral = initialCollateral x (leverage - 1); // 20 x (2 - 1) = 20

    uint totalCollateralPrice = convertCollateral(totalCollateral);
    uint borrowCollateralPrice = convertCollateral(borrowCollateral); // 20 x 0.5 = 10 USDC

    ```
    fn convertCollateral(unit256 collateral) returns(uint256 amount)
      PriceConverterLib.getConversionRate(collateral, lendingPool.collateralTokenUsdDataFeed(), lendingPool.loanTokenUsdDataFeed())
    ```

  - Calculate LP, LTV and health
    lendingPool.getLiquidationPrice(uint256 totalCollateral, uint256 borrowAmount) returns(uint8 liquidationPrice)
    lendingPool.getHealth(uint256 totalCollateralPrice, uint256 borrowAmount) returns(uint8 health)
    lendingPool.getLTV(uint256 totalCollateralPrice, uint256 borrowAmount) returns(uint8 ltv)

  Using Position

  - fn addLeverage(unit256 initialCollateral, unit256 borrowAmount)

    - Add collateral on FlashLoan
      lendingPool.flashloan(loanToken = USDC, borrowAmount = 10 USDC)

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

- fn editPosition({ address lendingPool, address positionAddress, uint8 collateral, uint8 leverage }) returns(bool status)
  Using Position

  - Calculate the difference
    newTotalCollateral = collateral x leverage; // 20 x 1.5 = 30

    - if (newTotalColateral < currTotalColateral)
      diffTotalColateral = currTotalColateral - newTotalColateral
      fn repayByPosition()
      collateral --;
      borrowShare --;
      totalCollateral --;
      totalBorrowAsset --;
      totalBorrowShare --;

    - if (newTotalColateral > currTotalColateral)
      diffTotalColateral = newTotalColateral - currTotalColateral
      fn borrowByPosition()

# fn updateLeverage( uint256 leverage );
NOTE : 
- Increasing leverage: Borrowing more funds against existing collateral.
- Decreasing leverage: Repaying part of the borrowed funds and reducing exposure.

- calculate to decide if its short or long

// find the borrow amount
 - uint256 oldBorrowAmount = borrowAmount;
 - newBorrowAmount = convertCollateral(baseCollateral * (_newLeverage - 1));

  if increase leverage: 
      uint256 additionalBorrow = newBorrowAmount - oldBorrowAmount;
      borrow as aditionalBorrow amount // include update borrowshares
      panggil flashloan
  if decrease leverage:
      repay by position

- Handle increasing/decreasing stuff : calculation in excel

    effectiveCollateral = newEffectiveCollateral;
    borrowShares = (newBorrowAmount * lendingPool.totalSupplyAssets()) / lendingPool.totalSupplyShares();
    liquidationPrice = lendingPool.getLiquidationPrice(effectiveCollateral, newBorrowAmount);
    health = lendingPool.getHealth(effectiveCollateral, newBorrowAmount);
    ltv = lendingPool.getLTV(effectiveCollateral, newBorrowAmount);
-  _emitUpdatePosition();

# fn close Position
- calculate borrowed amount
  convert from borrowshares

- swap
- repayByPosition()

- withdrawCollateralByPosition()

- reset position , emit

