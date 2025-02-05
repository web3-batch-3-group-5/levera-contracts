import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  PositionClosed,
  PositionCreated,
  Repaid
} from "../generated/LendingPool/LendingPool"

export function createPositionClosedEvent(user: Address): PositionClosed {
  let positionClosedEvent = changetype<PositionClosed>(newMockEvent())

  positionClosedEvent.parameters = new Array()

  positionClosedEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )

  return positionClosedEvent
}

export function createPositionCreatedEvent(
  user: Address,
  timestamp: BigInt
): PositionCreated {
  let positionCreatedEvent = changetype<PositionCreated>(newMockEvent())

  positionCreatedEvent.parameters = new Array()

  positionCreatedEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  positionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )

  return positionCreatedEvent
}

export function createRepaidEvent(user: Address, amount: BigInt): Repaid {
  let repaidEvent = changetype<Repaid>(newMockEvent())

  repaidEvent.parameters = new Array()

  repaidEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  repaidEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return repaidEvent
}
