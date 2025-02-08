include .env

# Default values
RPC_URL := https://${NETWORK}.g.alchemy.com/v2/${ALCHEMY_API_KEY}
DEF_SCRIPT_FILE := script/Deploy.s.sol

.PHONY: compile deploy deploy-verify script-deploy script-deploy-verify test verify

define forge_script
	forge script $(1) --broadcast --legacy $(2)
endef

define forge_create
	forge create $(1) --broadcast --legacy $(2)
endef

# Define a target to build the project
build:
	forge build --build-info --build-info-path out/build-info/

# Define a target to deploy using the specified network
deploy: build
	$(call forge_create,)

script-deploy: build
	$(call forge_script,$(DEF_SCRIPT_FILE))

# Define a target to verify deployment using the specified network
deploy-verify: build
	$(call forge_create,$(contract),--rpc-url $(RPC_URL) \
		--private-key ${WALLET_PRIVATE_KEY} \
		--verifier ${VERIFIER} \
		--verifier-api-key ${VERIFIER_API_KEY} \
		--verifier-url ${VERIFIER_URL} \
		--chain-id ${CHAIN_ID} \
		--verify)

script-deploy-verify: build
	$(call forge_script,$(DEF_SCRIPT_FILE),--rpc-url $(RPC_URL) \
	--private-key ${WALLET_PRIVATE_KEY} \
	--verifier ${VERIFIER} \
	--verifier-api-key ${VERIFIER_API_KEY} \
	--verifier-url ${VERIFIER_URL} \
	--chain-id ${CHAIN_ID} \
	--verify)

# Define a pre-existing contract address to verify deployment using the specified network
verify:
	forge verify-contract ${address} ${contract} --rpc-url $(RPC_URL) \
		--verifier ${VERIFIER} \
		--verifier-api-key ${VERIFIER_API_KEY} \
		--verifier-url ${VERIFIER_URL} \
		--chain-id ${CHAIN_ID}

# Define a target to compile the contracts
compile:
	forge compile

# Define a target to run tests
test:
	@[ "${contract}" ] && forge test --match-contract $(contract) -vvv || ( forge test )

# Define a target to display help information
help:
	@echo "Makefile targets:"
	@echo "  deploy          				- Deploy contracts using forge create on the specified network"
	@echo "  deploy-verify   				- Deploy and verify contracts using forge create on the specified network"
	@echo "  script-deploy   				- Deploy contracts using forge script on the specified network"
	@echo "  script-deploy-verify   - Deploy and verify contracts using forge script on the specified network"
	@echo "  compile         				- Compile the contracts"
	@echo "  test            				- Run tests"
	@echo "  help            				- Display this help information"