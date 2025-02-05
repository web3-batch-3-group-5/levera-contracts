include .env

# Default values
RPC_URL := https://${NETWORK}.g.alchemy.com/v2/${ALCHEMY_API_KEY}

.PHONY: compile deploy deploy-verify test verify

define forge_script
	forge script script/Deploy.s.sol --broadcast --legacy $(1)
endef

# Define a target to build the project
build:
	forge build --build-info --build-info-path out/build-info/

# Define a target to deploy using the specified network
deploy: build
	$(call forge_script,)

# Define a target to verify deployment using the specified network
deploy-verify: build
	$(call forge_script,--rpc-url $(RPC_URL) --private-key ${WALLET_PRIVATE_KEY} --verifier ${VERIFIER} --verifier-api-key ${VERIFIER_API_KEY} --verifier-url ${VERIFIER_URL} --chain-id ${CHAIN_ID} --verify)

# Define a target to compile the contracts
compile:
	forge compile

# Define a target to run tests
test:
	@[ "${contract}" ] && forge test --match-contract $(contract) -vvv || ( forge test )

# Define a target to display help information
help:
	@echo "Makefile targets:"
	@echo "  deploy          - Deploy contracts using the specified network"
	@echo "  deploy-verify   - Deploy and verify contracts using the specified network"
	@echo "  compile         - Compile the contracts"
	@echo "  test            - Run tests"
	@echo "  help            - Display this help information"