import {
  PositionClosed as PositionClosedEvent,
  PositionCreated as PositionCreatedEvent,
  Repaid as RepaidEvent,
  Supply as SupplyEvent
} from "../generated/LendingPool/LendingPool"
import {
  PositionClosed,
  PositionCreated,
  Repaid,
  Supply
} from "../generated/schema"

export function handlePositionClosed(event: PositionClosedEvent): void {
  let entity = new PositionClosed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.caller = event.params.caller
  entity.onBehalf = event.params.onBehalf
  entity.collateralAmount = event.params.collateralAmount
  entity.borrowAmount = event.params.borrowAmount
  entity.timestamp = event.params.timestamp
  entity.isActive = event.params.isActive

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePositionCreated(event: PositionCreatedEvent): void {
  let entity = new PositionCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.caller = event.params.caller
  entity.onBehalf = event.params.onBehalf
  entity.collateralAmount = event.params.collateralAmount
  entity.borrowAmount = event.params.borrowAmount
  entity.timestamp = event.params.timestamp
  entity.isActive = event.params.isActive

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRepaid(event: RepaidEvent): void {
  let entity = new Repaid(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.caller = event.params.caller
  entity.onBehalf = event.params.onBehalf
  entity.collateralAmount = event.params.collateralAmount
  entity.borrowAmount = event.params.borrowAmount
  entity.timestamp = event.params.timestamp
  entity.isActive = event.params.isActive

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSupply(event: SupplyEvent): void {
  let entity = new Supply(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.caller = event.params.caller

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
