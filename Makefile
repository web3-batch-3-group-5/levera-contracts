include .env

.PHONY: compile deploy deploy-verify test verify

define forge_script
	forge script ./script/Deploy.s.sol --broadcast --legacy --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} $(1) -vvvv
endef

# Define a target to build the project
build:
	forge build --build-info --build-info-path out/build-info/

# Define a target to deploy using the specified network
deploy: build
	@cmd="$(call forge_script, --skip-simulation --disable-block-gas-limit)"; \
	if [ -n "$$CHAIN_ID" ]; then cmd="$$cmd --chain-id $$CHAIN_ID"; fi; \
	eval $$cmd

# Define a target to verify deployment using the specified network
deploy-verify: build
	@cmd="$(call forge_script, --verifier ${VERIFIER} --verifier-url ${VERIFIER_URL} --verify)"; \
	if [ -n "$$VERIFIER_API_KEY" ]; then cmd="$$cmd --verifier-api-key $$VERIFIER_API_KEY"; fi; \
	if [ -n "$$CHAIN_ID" ]; then cmd="$$cmd --chain-id $$CHAIN_ID"; fi; \
	eval $$cmd

# Define a pre-existing contract address to verify deployment using the specified network
# Ex: make verify address=0x path=src/Vault.sol:Vault
verify:
	@cmd="forge verify-contract ${address} ${path} --watch --rpc-url ${RPC_URL} \
		--verifier ${VERIFIER} --verifier-url ${VERIFIER_URL}"; \
	if [ -n "$$VERIFIER_API_KEY" ]; then cmd="$$cmd --verifier-api-key $$VERIFIER_API_KEY"; fi; \
	if [ -n "$$CHAIN_ID" ]; then cmd="$$cmd --chain-id $$CHAIN_ID"; fi; \
	eval $$cmd

# Define a target to compile the contracts
compile:
	forge compile

# Define a target to run tests
test:
	@[ "${contract}" ] && forge test --match-contract $(contract) -vvv || ( forge test )

# Define a target to display help information
help:
	@echo "Makefile targets:"
	@echo "  deploy          				- Deploy contracts on the specified network"
	@echo "  deploy-verify   				- Deploy and verify contracts on the specified network"
	@echo "  compile         				- Compile the contracts"
	@echo "  test            				- Run tests"
	@echo "  help            				- Display this help information"