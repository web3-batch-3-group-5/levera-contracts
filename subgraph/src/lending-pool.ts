import {
  PositionClosed as PositionClosedEvent,
  PositionCreated as PositionCreatedEvent,
  Repaid as RepaidEvent
} from "../generated/LendingPool/LendingPool"
import { PositionClosed, PositionCreated, Repaid } from "../generated/schema"

export function handlePositionClosed(event: PositionClosedEvent): void {
  let entity = new PositionClosed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.user = event.params.user

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePositionCreated(event: PositionCreatedEvent): void {
  let entity = new PositionCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.user = event.params.user
  entity.timestamp = event.params.timestamp

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRepaid(event: RepaidEvent): void {
  let entity = new Repaid(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.user = event.params.user
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
