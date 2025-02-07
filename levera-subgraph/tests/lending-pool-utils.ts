import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  PositionClosed,
  PositionCreated,
  Repaid,
  Supply
} from "../generated/LendingPool/LendingPool"

export function createPositionClosedEvent(
  caller: Address,
  onBehalf: Address,
  collateralAmount: BigInt,
  borrowAmount: BigInt,
  timestamp: BigInt,
  isActive: boolean
): PositionClosed {
  let positionClosedEvent = changetype<PositionClosed>(newMockEvent())

  positionClosedEvent.parameters = new Array()

  positionClosedEvent.parameters.push(
    new ethereum.EventParam("caller", ethereum.Value.fromAddress(caller))
  )
  positionClosedEvent.parameters.push(
    new ethereum.EventParam("onBehalf", ethereum.Value.fromAddress(onBehalf))
  )
  positionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "collateralAmount",
      ethereum.Value.fromUnsignedBigInt(collateralAmount)
    )
  )
  positionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "borrowAmount",
      ethereum.Value.fromUnsignedBigInt(borrowAmount)
    )
  )
  positionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )
  positionClosedEvent.parameters.push(
    new ethereum.EventParam("isActive", ethereum.Value.fromBoolean(isActive))
  )

  return positionClosedEvent
}

export function createPositionCreatedEvent(
  caller: Address,
  onBehalf: Address,
  collateralAmount: BigInt,
  borrowAmount: BigInt,
  timestamp: BigInt,
  isActive: boolean
): PositionCreated {
  let positionCreatedEvent = changetype<PositionCreated>(newMockEvent())

  positionCreatedEvent.parameters = new Array()

  positionCreatedEvent.parameters.push(
    new ethereum.EventParam("caller", ethereum.Value.fromAddress(caller))
  )
  positionCreatedEvent.parameters.push(
    new ethereum.EventParam("onBehalf", ethereum.Value.fromAddress(onBehalf))
  )
  positionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "collateralAmount",
      ethereum.Value.fromUnsignedBigInt(collateralAmount)
    )
  )
  positionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "borrowAmount",
      ethereum.Value.fromUnsignedBigInt(borrowAmount)
    )
  )
  positionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )
  positionCreatedEvent.parameters.push(
    new ethereum.EventParam("isActive", ethereum.Value.fromBoolean(isActive))
  )

  return positionCreatedEvent
}

export function createRepaidEvent(
  caller: Address,
  onBehalf: Address,
  collateralAmount: BigInt,
  borrowAmount: BigInt,
  timestamp: BigInt,
  isActive: boolean
): Repaid {
  let repaidEvent = changetype<Repaid>(newMockEvent())

  repaidEvent.parameters = new Array()

  repaidEvent.parameters.push(
    new ethereum.EventParam("caller", ethereum.Value.fromAddress(caller))
  )
  repaidEvent.parameters.push(
    new ethereum.EventParam("onBehalf", ethereum.Value.fromAddress(onBehalf))
  )
  repaidEvent.parameters.push(
    new ethereum.EventParam(
      "collateralAmount",
      ethereum.Value.fromUnsignedBigInt(collateralAmount)
    )
  )
  repaidEvent.parameters.push(
    new ethereum.EventParam(
      "borrowAmount",
      ethereum.Value.fromUnsignedBigInt(borrowAmount)
    )
  )
  repaidEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )
  repaidEvent.parameters.push(
    new ethereum.EventParam("isActive", ethereum.Value.fromBoolean(isActive))
  )

  return repaidEvent
}

export function createSupplyEvent(caller: Address): Supply {
  let supplyEvent = changetype<Supply>(newMockEvent())

  supplyEvent.parameters = new Array()

  supplyEvent.parameters.push(
    new ethereum.EventParam("caller", ethereum.Value.fromAddress(caller))
  )

  return supplyEvent
}
