# OCR2VRF Standalone Tool

This is a standalone implementation of Chainlink's OCR2VRF (Off-Chain Reporting 2 Verifiable Random Function) functionality.

## Overview

OCR2VRF combines Chainlink's OCR2 protocol with VRF to provide secure, verifiable randomness through Distributed Key Generation (DKG).

The tool allows you to:
- Deploy and configure a DKG contract
- Deploy and configure a VRF coordinator and beacon
- Request and verify randomness
- Manage subscriptions

## Directory Structure

- `main.go` - Entry point containing the command-line interface
- `setup_dkg.go` - DKG setup and configuration
- `setup_ocr2vrf.go` - OCR2VRF setup and node configuration
- `util.go` - Utility functions for contract deployment and interaction
- `verify.go` - Functions for verifying randomness
- `helpers/` - Common helper functions for Ethereum interaction

## Requirements

- Go 1.21 or later
- Access to an Ethereum node
- Private key with ETH for deploying contracts and sending transactions

## Building the Tool

To build the OCR2VRF tool:

```bash
go build -o ocr2vrf .
```

This will create an executable named `ocr2vrf` in the current directory.

## Environment Variables

Before running the tool, set the following environment variables:

- `ETH_URL` - URL of the Ethereum node (e.g., `http://localhost:8545`)
- `ETH_CHAIN_ID` - Chain ID of the Ethereum network (e.g., `1337` for local development)
- `ACCOUNT_KEY` - Private key for transactions (without 0x prefix)
- `GAS_LIMIT` - (Optional) Gas limit for transactions

Example:
```bash
export ETH_URL=http://localhost:8545
export ETH_CHAIN_ID=1337
export ACCOUNT_KEY=your_private_key_without_0x_prefix
```

## Available Commands

### DKG (Distributed Key Generation)

#### Deploy DKG Contract
```bash
./ocr2vrf dkg-deploy
```

#### Add Client to DKG
```bash
./ocr2vrf dkg-add-client \
  --dkg-address 0x_your_dkg_address \
  --key-id your_key_id \
  --client-address 0x_your_client_address
```

#### Remove Client from DKG
```bash
./ocr2vrf dkg-remove-client \
  --dkg-address 0x_your_dkg_address \
  --key-id your_key_id \
  --client-address 0x_your_client_address
```

#### Configure DKG
```bash
./ocr2vrf dkg-set-config \
  --dkg-address 0x_your_dkg_address \
  --key-id your_key_id \
  --onchain-pub-keys comma_separated_onchain_pubkeys \
  --offchain-pub-keys comma_separated_offchain_pubkeys \
  --config-pub-keys comma_separated_config_pubkeys \
  --peer-ids comma_separated_peer_ids \
  --transmitters comma_separated_transmitter_addresses \
  --dkg-encryption-pub-keys comma_separated_encryption_pubkeys \
  --dkg-signing-pub-keys comma_separated_signing_pubkeys \
  --schedule 1,1,1,1,1 \
  --f 1 \
  --delta-progress 30s \
  --delta-resend 10s \
  --delta-round 10s \
  --delta-grace 20s \
  --delta-stage 20s \
  --max-rounds 3
```

#### Setup DKG Nodes
```bash
./ocr2vrf dkg-setup
```

### VRF Coordinator

#### Deploy VRF Coordinator
```bash
./ocr2vrf coordinator-deploy \
  --beacon-period-blocks 1 \
  --link-address 0x_your_link_token_address \
  --link-eth-feed 0x_your_link_eth_feed_address
```

#### Set Producer for Coordinator
```bash
./ocr2vrf coordinator-set-producer \
  --coordinator-address 0x_your_coordinator_address \
  --beacon-address 0x_your_beacon_address
```

#### Create Subscription
```bash
./ocr2vrf coordinator-create-sub \
  --coordinator-address 0x_your_coordinator_address
```

#### Add Consumer to Subscription
```bash
./ocr2vrf coordinator-add-consumer \
  --coordinator-address 0x_your_coordinator_address \
  --consumer-address 0x_your_consumer_address \
  --sub-id your_subscription_id
```

#### Get Subscription Details
```bash
./ocr2vrf coordinator-get-sub \
  --coordinator-address 0x_your_coordinator_address \
  --sub-id your_subscription_id
```

#### Fund Subscription
```bash
./ocr2vrf coordinator-fund-sub \
  --coordinator-address 0x_your_coordinator_address \
  --link-address 0x_your_link_address \
  --funding-amount 5e18 \
  --sub-id your_subscription_id
```

#### Request Randomness
```bash
./ocr2vrf coordinator-request-randomness \
  --coordinator-address 0x_your_coordinator_address \
  --num-words 1 \
  --sub-id your_subscription_id \
  --conf-delay 1
```

#### Redeem Randomness
```bash
./ocr2vrf coordinator-redeem-randomness \
  --coordinator-address 0x_your_coordinator_address \
  --sub-id your_subscription_id \
  --request-id your_request_id
```

### VRF Beacon

#### Deploy VRF Beacon
```bash
./ocr2vrf beacon-deploy \
  --coordinator-address 0x_your_coordinator_address \
  --link-address 0x_your_link_token_address \
  --dkg-address 0x_your_dkg_address \
  --key-id your_key_id
```

#### Configure VRF Beacon
```bash
./ocr2vrf beacon-set-config \
  --beacon-address 0x_your_beacon_address \
  --conf-delays 1,2,3,4,5,6,7,8 \
  --onchain-pub-keys comma_separated_onchain_pubkeys \
  --offchain-pub-keys comma_separated_offchain_pubkeys \
  --config-pub-keys comma_separated_config_pubkeys \
  --peer-ids comma_separated_peer_ids \
  --transmitters comma_separated_transmitter_addresses \
  --schedule 1,1,1,1,1 \
  --f 1 \
  --delta-progress 30s \
  --cache-eviction-window 60 \
  --batch-gas-limit 5000000 \
  --coordinator-overhead 50000 \
  --callback-overhead 50000 \
  --block-gas-overhead 50000 \
  --lookback-blocks 1000
```

#### Set Payees for Beacon
```bash
./ocr2vrf beacon-set-payees \
  --beacon-address 0x_your_beacon_address \
  --transmitters comma_separated_transmitter_addresses \
  --payees comma_separated_payee_addresses
```

#### Get Beacon Info
```bash
./ocr2vrf beacon-info \
  --beacon-address 0x_your_beacon_address
```

### Consumer Operations

#### Deploy VRF Consumer
```bash
./ocr2vrf consumer-deploy \
  --coordinator-address 0x_your_coordinator_address \
  --should-fail false \
  --beacon-period-blocks 1
```

#### Deploy Load Test Consumer
```bash
./ocr2vrf deploy-load-test-consumer \
  --coordinator-address 0x_your_coordinator_address \
  --beacon-period-blocks 1
```

#### Request Randomness from Consumer
```bash
./ocr2vrf consumer-request-randomness \
  --consumer-address 0x_your_consumer_address \
  --num-words 1 \
  --sub-id your_subscription_id \
  --conf-delay 1
```

#### Redeem Randomness from Consumer
```bash
./ocr2vrf consumer-redeem-randomness \
  --consumer-address 0x_your_consumer_address \
  --sub-id your_subscription_id \
  --request-id your_request_id \
  --num-words 1
```

#### Request Randomness with Callback
```bash
./ocr2vrf consumer-request-callback \
  --consumer-address 0x_your_consumer_address \
  --num-words 1 \
  --sub-id your_subscription_id \
  --conf-delay 1 \
  --cb-gas-limit 100000
```

#### Request Batch Randomness with Callback
```bash
./ocr2vrf consumer-request-callback-batch \
  --consumer-address 0x_your_consumer_address \
  --num-words 1 \
  --sub-id your_subscription_id \
  --conf-delay 1 \
  --batch-size 10 \
  --cb-gas-limit 200000
```

#### Request Batch Randomness (Load Test)
```bash
./ocr2vrf consumer-request-callback-batch-load-test \
  --consumer-address 0x_your_consumer_address \
  --num-words 1 \
  --sub-id your_subscription_id \
  --conf-delay 1 \
  --batch-size 10 \
  --batch-count 5 \
  --cb-gas-limit 200000
```

#### Read Randomness from Consumer
```bash
./ocr2vrf consumer-read-randomness \
  --consumer-address 0x_your_consumer_address \
  --request-id your_request_id \
  --num-words 1
```

#### Get Load Test Results
```bash
./ocr2vrf get-load-test-results \
  --consumer-address 0x_your_consumer_address
```

### OCR2VRF Node Operations

#### Setup OCR2VRF Nodes
```bash
./ocr2vrf ocr2vrf-setup
```

#### Setup OCR2VRF Nodes with Forwarder Infrastructure
```bash
./ocr2vrf ocr2vrf-setup-infra-forwarder
```

#### Fund OCR2VRF Nodes
```bash
./ocr2vrf ocr2vrf-fund-nodes \
  --eth-sending-keys comma_separated_sending_keys \
  --funding-amount 1e18
```

### Verification & Utilities

#### Verify Beacon Randomness
```bash
./ocr2vrf verify-beacon-randomness \
  --dkg-address 0x_your_dkg_address \
  --beacon-address 0x_your_beacon_address \
  --coordinator-address 0x_your_coordinator_address \
  --height block_height \
  --conf-delay 1 \
  --search-window 200
```

#### Check LINK Balance
```bash
./ocr2vrf link-balance \
  --link-address 0x_your_link_address
```

#### Get ETH Balances
```bash
./ocr2vrf get-balances \
  --addresses comma_separated_addresses
```

## Workflow Example

Here's a typical workflow for setting up OCR2VRF:

1. Deploy the DKG contract:
   ```bash
   ./ocr2vrf dkg-deploy
   ```

2. Deploy the VRF Coordinator:
   ```bash
   ./ocr2vrf coordinator-deploy \
     --beacon-period-blocks 1 \
     --link-address 0x_your_link_token_address \
     --link-eth-feed 0x_your_link_eth_feed_address
   ```

3. Deploy the VRF Beacon:
   ```bash
   ./ocr2vrf beacon-deploy \
     --coordinator-address 0x_your_coordinator_address \
     --link-address 0x_your_link_token_address \
     --dkg-address 0x_your_dkg_address \
     --key-id your_key_id
   ```

4. Set the VRF Beacon as producer for the Coordinator:
   ```bash
   ./ocr2vrf coordinator-set-producer \
     --coordinator-address 0x_your_coordinator_address \
     --beacon-address 0x_your_beacon_address
   ```

5. Create a subscription:
   ```bash
   ./ocr2vrf coordinator-create-sub \
     --coordinator-address 0x_your_coordinator_address
   ```

6. Fund the subscription:
   ```bash
   ./ocr2vrf coordinator-fund-sub \
     --coordinator-address 0x_your_coordinator_address \
     --link-address 0x_your_link_address \
     --funding-amount 5e18 \
     --sub-id your_subscription_id
   ```

7. Deploy a consumer contract:
   ```bash
   ./ocr2vrf consumer-deploy \
     --coordinator-address 0x_your_coordinator_address \
     --beacon-period-blocks 1
   ```

8. Add the consumer to the subscription:
   ```bash
   ./ocr2vrf coordinator-add-consumer \
     --coordinator-address 0x_your_coordinator_address \
     --consumer-address 0x_your_consumer_address \
     --sub-id your_subscription_id
   ```

9. Request randomness:
   ```bash
   ./ocr2vrf consumer-request-randomness \
     --consumer-address 0x_your_consumer_address \
     --num-words 1 \
     --sub-id your_subscription_id \
     --conf-delay 1
   ```

10. Verify the randomness:
    ```bash
    ./ocr2vrf verify-beacon-randomness \
      --dkg-address 0x_your_dkg_address \
      --beacon-address 0x_your_beacon_address \
      --coordinator-address 0x_your_coordinator_address \
      --height block_height \
      --conf-delay 1
    ```