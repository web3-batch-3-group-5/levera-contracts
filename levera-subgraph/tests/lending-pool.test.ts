import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { PositionClosed } from "../generated/schema"
import { PositionClosed as PositionClosedEvent } from "../generated/LendingPool/LendingPool"
import { handlePositionClosed } from "../src/lending-pool"
import { createPositionClosedEvent } from "./lending-pool-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let caller = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let onBehalf = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let collateralAmount = BigInt.fromI32(234)
    let borrowAmount = BigInt.fromI32(234)
    let timestamp = BigInt.fromI32(234)
    let isActive = "boolean Not implemented"
    let newPositionClosedEvent = createPositionClosedEvent(
      caller,
      onBehalf,
      collateralAmount,
      borrowAmount,
      timestamp,
      isActive
    )
    handlePositionClosed(newPositionClosedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("PositionClosed created and stored", () => {
    assert.entityCount("PositionClosed", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "PositionClosed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "caller",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "PositionClosed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "onBehalf",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "PositionClosed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "collateralAmount",
      "234"
    )
    assert.fieldEquals(
      "PositionClosed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "borrowAmount",
      "234"
    )
    assert.fieldEquals(
      "PositionClosed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "timestamp",
      "234"
    )
    assert.fieldEquals(
      "PositionClosed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "isActive",
      "boolean Not implemented"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
