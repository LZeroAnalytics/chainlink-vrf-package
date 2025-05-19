GO_SERVICE_NAME = "ocr2vrf-cli"
GO_IMAGE = "golang:1.21-alpine"  # Base Go image

# Common command constants
CMD_SETUP = "setup"
CMD_VERIFY = "verify"
CMD_KEYS = "keys"
CMD_JOBS = "jobs"

def init(plan, private_key, eth_url, chain_id, gas_limit="8000000"):
    # Upload source code directly
    go_source = plan.upload_files("./ocr2vrf-cli")
    
    # Create service with base Go image
    go_service = plan.add_service(
        name = GO_SERVICE_NAME,
        config = ServiceConfig(
            image = GO_IMAGE,
            entrypoint = ["tail", "-f", "/dev/null"],  # Keep container running
            files = {
                "/app": go_source,  # Mount source code
            },
            env_vars = {
                "ETH_URL": eth_url,
                "ETH_CHAIN_ID": str(chain_id),
                "ACCOUNT_KEY": private_key,
                "GAS_LIMIT": str(gas_limit)
            }
        )
    )
    # Build the Go application inside the container
    plan.exec(
        service_name = GO_SERVICE_NAME,
        recipe = ExecRecipe(
            command = ["sh", "-c", "cd /app && go build -o /usr/local/bin/ocr2vrf ."]
        )
    )
    return go_service

def run_command(plan, args):
    result = plan.exec(
        service_name = GO_SERVICE_NAME,
        recipe = ExecRecipe(
            command = ["/usr/local/bin/ocr2vrf"] + args
        )
    )
    return result

# ─────────────────── DEPLOYMENT COMMANDS ───────────────────

def deploy_dkg(plan):
    return run_command(plan, ["dkg-deploy"])

def deploy_coordinator(plan, beacon_period_blocks=1, link_address="", link_eth_feed=""):
    cmd = ["coordinator-deploy", 
          "--beacon-period-blocks", str(beacon_period_blocks),  # ~ beacon period in number of blocks
          "--link-address", link_address,  # ~ link contract address
          "--link-eth-feed", link_eth_feed]  # ~ link/eth feed address
    return run_command(plan, cmd)

def deploy_beacon(plan, coordinator_address, link_address, dkg_address, key_id):
    cmd = ["beacon-deploy",
          "--coordinator-address", coordinator_address,  # ~ coordinator contract address
          "--link-address", link_address,  # ~ link contract address
          "--dkg-address", dkg_address,  # ~ dkg contract address
          "--key-id", key_id]  # ~ key ID
    return run_command(plan, cmd)

def deploy_consumer(plan, coordinator_address, should_fail=False, beacon_period_blocks=1):
    cmd = ["consumer-deploy",
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator address
          "--beacon-period-blocks", str(beacon_period_blocks)]  # ~ beacon period in number of blocks
    if should_fail:
        cmd.extend(["--should-fail", "true"])  # ~ shouldFail flag
    return run_command(plan, cmd)

def deploy_load_test_consumer(plan, coordinator_address, beacon_period_blocks=1):
    cmd = ["deploy-load-test-consumer",
          "--coordinator-address", coordinator_address,  # ~ coordinator address
          "--beacon-period-blocks", str(beacon_period_blocks)]  # ~ beacon period in number of blocks
    return run_command(plan, cmd)

# ─────────────────── DKG COMMANDS ───────────────────

def dkg_add_client(plan, dkg_address, key_id, client_address):
    cmd = ["dkg-add-client",
          "--dkg-address", dkg_address,  # ~ DKG contract address
          "--key-id", key_id,  # ~ key ID
          "--client-address", client_address]  # ~ client address
    return run_command(plan, cmd)

def dkg_remove_client(plan, dkg_address, key_id, client_address):
    cmd = ["dkg-remove-client",
          "--dkg-address", dkg_address,  # ~ DKG contract address
          "--key-id", key_id,  # ~ key ID
          "--client-address", client_address]  # ~ client address
    return run_command(plan, cmd)

def dkg_set_config(plan, dkg_address, key_id, 
                  onchain_pub_keys="", offchain_pub_keys="", config_pub_keys="", 
                  peer_ids="", transmitters="", dkg_encryption_pub_keys="", 
                  dkg_signing_pub_keys="", schedule="", f=1,
                  delta_progress="30s", delta_resend="10s", delta_round="10s", 
                  delta_grace="20s", delta_stage="20s", max_rounds=3,
                  max_duration_query="10ms", max_duration_observation="10s", 
                  max_duration_report="10s", max_duration_accept="10ms", 
                  max_duration_transmit="1s"):
    cmd = ["dkg-set-config",
          "--dkg-address", dkg_address,  # ~ DKG contract address
          "--key-id", key_id,  # ~ key ID
          "--onchain-pub-keys", onchain_pub_keys,  # ~ comma-separated list of OCR on-chain pubkeys
          "--offchain-pub-keys", offchain_pub_keys,  # ~ comma-separated list of OCR off-chain pubkeys
          "--config-pub-keys", config_pub_keys,  # ~ comma-separated list of OCR config pubkeys
          "--peer-ids", peer_ids,  # ~ comma-separated list of peer IDs
          "--transmitters", transmitters,  # ~ comma-separated list transmitters
          "--dkg-encryption-pub-keys", dkg_encryption_pub_keys,  # ~ comma-separated list of DKG encryption pubkeys
          "--dkg-signing-pub-keys", dkg_signing_pub_keys,  # ~ comma-separated list of DKG signing pubkeys
          "--schedule", schedule,  # ~ comma-separted list of transmission schedule
          "--f", str(f),  # ~ number of faulty oracles
          "--delta-progress", delta_progress,  # ~ duration of delta progress
          "--delta-resend", delta_resend,  # ~ duration of delta resend
          "--delta-round", delta_round,  # ~ duration of delta round
          "--delta-grace", delta_grace,  # ~ duration of delta grace
          "--delta-stage", delta_stage,  # ~ duration of delta stage
          "--max-rounds", str(max_rounds),  # ~ maximum number of rounds
          "--max-duration-query", max_duration_query,  # ~ maximum duration of query
          "--max-duration-observation", max_duration_observation,  # ~ maximum duration of observation method
          "--max-duration-report", max_duration_report,  # ~ maximum duration of report method
          "--max-duration-accept", max_duration_accept,  # ~ maximum duration of shouldAcceptFinalizedReport method
          "--max-duration-transmit", max_duration_transmit]  # ~ maximum duration of shouldTransmitAcceptedReport method
    return run_command(plan, cmd)

def dkg_setup(plan):
    return run_command(plan, ["dkg-setup"])

# ─────────────────── BEACON COMMANDS ───────────────────

def beacon_set_config(plan, beacon_address, 
                     conf_delays="1,2,3,4,5,6,7,8",
                     onchain_pub_keys="", offchain_pub_keys="", config_pub_keys="", 
                     peer_ids="", transmitters="", schedule="", f=1,
                     delta_progress="30s", delta_resend="10s", delta_round="10s", 
                     delta_grace="20s", delta_stage="20s",
                     cache_eviction_window=60, batch_gas_limit=5000000,
                     coordinator_overhead=50000, callback_overhead=50000,
                     block_gas_overhead=50000, lookback_blocks=1000,
                     max_rounds=3, max_duration_query="10ms", 
                     max_duration_observation="10s", max_duration_report="10s", 
                     max_duration_accept="5s", max_duration_transmit="1s"):
    cmd = ["beacon-set-config",
          "--beacon-address", beacon_address,  # ~ VRF beacon contract address
          "--conf-delays", conf_delays,  # ~ comma-separted list of 8 confirmation delays
          "--onchain-pub-keys", onchain_pub_keys,  # ~ comma-separated list of OCR on-chain pubkeys
          "--offchain-pub-keys", offchain_pub_keys,  # ~ comma-separated list of OCR off-chain pubkeys
          "--config-pub-keys", config_pub_keys,  # ~ comma-separated list of OCR config pubkeys
          "--peer-ids", peer_ids,  # ~ comma-separated list of peer IDs
          "--transmitters", transmitters,  # ~ comma-separated list transmitters
          "--schedule", schedule,  # ~ comma-separted list of transmission schedule
          "--f", str(f),  # ~ number of faulty oracles
          "--delta-progress", delta_progress,  # ~ duration of delta progress
          "--delta-resend", delta_resend,  # ~ duration of delta resend
          "--delta-round", delta_round,  # ~ duration of delta round
          "--delta-grace", delta_grace,  # ~ duration of delta grace
          "--delta-stage", delta_stage,  # ~ duration of delta stage
          "--cache-eviction-window", str(cache_eviction_window),  # ~ cache eviction window, in seconds
          "--batch-gas-limit", str(batch_gas_limit),  # ~ batch gas limit
          "--coordinator-overhead", str(coordinator_overhead),  # ~ coordinator overhead
          "--callback-overhead", str(callback_overhead),  # ~ callback overhead
          "--block-gas-overhead", str(block_gas_overhead),  # ~ block gas overhead
          "--lookback-blocks", str(lookback_blocks),  # ~ lookback blocks
          "--max-rounds", str(max_rounds),  # ~ maximum number of rounds
          "--max-duration-query", max_duration_query,  # ~ maximum duration of query
          "--max-duration-observation", max_duration_observation,  # ~ maximum duration of observation method
          "--max-duration-report", max_duration_report,  # ~ maximum duration of report method
          "--max-duration-accept", max_duration_accept,  # ~ maximum duration of shouldAcceptFinalizedReport method
          "--max-duration-transmit", max_duration_transmit]  # ~ maximum duration of shouldTransmitAcceptedReport method
    return run_command(plan, cmd)

def beacon_info(plan, beacon_address):
    cmd = ["beacon-info", 
          "--beacon-address", beacon_address]  # ~ VRF beacon contract address
    return run_command(plan, cmd)

def beacon_set_payees(plan, beacon_address, transmitters, payees):
    cmd = ["beacon-set-payees",
          "--beacon-address", beacon_address,  # ~ VRF beacon contract address
          "--transmitters", transmitters,  # ~ comma-separated list of transmitters
          "--payees", payees]  # ~ comma-separated list of payees
    return run_command(plan, cmd)

# ─────────────────── COORDINATOR COMMANDS ───────────────────

def coordinator_set_producer(plan, coordinator_address, beacon_address):
    cmd = ["coordinator-set-producer",
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator contract address
          "--beacon-address", beacon_address]  # ~ VRF beacon contract address
    return run_command(plan, cmd)

def coordinator_request_randomness(plan, coordinator_address, sub_id, num_words=1, conf_delay=1):
    cmd = ["coordinator-request-randomness",
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator contract address
          "--sub-id", sub_id,  # ~ subscription ID
          "--num-words", str(num_words),  # ~ number of words to request
          "--conf-delay", str(conf_delay)]  # ~ confirmation delay
    return run_command(plan, cmd)

def coordinator_redeem_randomness(plan, coordinator_address, sub_id, request_id):
    cmd = ["coordinator-redeem-randomness",
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator contract address
          "--sub-id", sub_id,  # ~ subscription ID
          "--request-id", str(request_id)]  # ~ request ID
    return run_command(plan, cmd)

def coordinator_create_sub(plan, coordinator_address):
    cmd = ["coordinator-create-sub", 
          "--coordinator-address", coordinator_address]  # ~ VRF coordinator contract address
    return run_command(plan, cmd)

def coordinator_add_consumer(plan, coordinator_address, consumer_address, sub_id):
    cmd = ["coordinator-add-consumer",
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator contract address
          "--consumer-address", consumer_address,  # ~ VRF consumer contract address
          "--sub-id", sub_id]  # ~ subscription ID
    return run_command(plan, cmd)

def coordinator_get_sub(plan, coordinator_address, sub_id):
    cmd = ["coordinator-get-sub",
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator contract address
          "--sub-id", sub_id]  # ~ subscription ID
    return run_command(plan, cmd)

def coordinator_fund_sub(plan, coordinator_address, link_address, sub_id, funding_amount="5e18"):
    cmd = ["coordinator-fund-sub",
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator contract address
          "--link-address", link_address,  # ~ link-address
          "--sub-id", sub_id,  # ~ subscription ID
          "--funding-amount", funding_amount]  # ~ funding amount in juels. can use scientific notation, e.g 10e18 for 10 LINK
    return run_command(plan, cmd)

# ─────────────────── CONSUMER COMMANDS ───────────────────

def consumer_request_randomness(plan, consumer_address, sub_id, num_words=1, conf_delay=1):
    cmd = ["consumer-request-randomness",
          "--consumer-address", consumer_address,  # ~ VRF coordinator consumer address
          "--sub-id", sub_id,  # ~ subscription ID
          "--num-words", str(num_words),  # ~ number of words to request
          "--conf-delay", str(conf_delay)]  # ~ confirmation delay
    return run_command(plan, cmd)

def consumer_redeem_randomness(plan, consumer_address, request_id, sub_id="0", num_words=1):
    cmd = ["consumer-redeem-randomness",
          "--consumer-address", consumer_address,  # ~ VRF coordinator consumer address
          "--request-id", request_id,  # ~ request ID
          "--sub-id", sub_id,  # ~ subscription ID
          "--num-words", str(num_words)]  # ~ number of words to print after redeeming
    return run_command(plan, cmd)

def consumer_request_callback(plan, consumer_address, sub_id, num_words=1, conf_delay=1, cb_gas_limit=100000):
    cmd = ["consumer-request-callback",
          "--consumer-address", consumer_address,  # ~ VRF coordinator consumer address
          "--sub-id", sub_id,  # ~ subscription ID
          "--num-words", str(num_words),  # ~ number of words to request
          "--conf-delay", str(conf_delay),  # ~ confirmation delay
          "--cb-gas-limit", str(cb_gas_limit)]  # ~ callback gas limit
    return run_command(plan, cmd)

def consumer_read_randomness(plan, consumer_address, request_id, num_words=1):
    cmd = ["consumer-read-randomness",
          "--consumer-address", consumer_address,  # ~ VRF coordinator consumer address
          "--request-id", request_id,  # ~ VRF request ID
          "--num-words", str(num_words)]  # ~ number of words to fetch
    return run_command(plan, cmd)

def consumer_request_callback_batch(plan, consumer_address, sub_id, batch_size=1, num_words=1, conf_delay=1, cb_gas_limit=200000):
    cmd = ["consumer-request-callback-batch",
          "--consumer-address", consumer_address,  # ~ VRF beacon consumer address
          "--sub-id", sub_id,  # ~ subscription ID
          "--batch-size", str(batch_size),  # ~ batch size
          "--num-words", str(num_words),  # ~ number of words to request
          "--conf-delay", str(conf_delay),  # ~ confirmation delay
          "--cb-gas-limit", str(cb_gas_limit)]  # ~ callback gas limit
    return run_command(plan, cmd)

def consumer_request_callback_batch_load_test(plan, consumer_address, sub_id, batch_size=1, batch_count=1, num_words=1, conf_delay=1, cb_gas_limit=200000):
    cmd = ["consumer-request-callback-batch-load-test",
          "--consumer-address", consumer_address,  # ~ VRF beacon batch consumer address
          "--sub-id", sub_id,  # ~ subscription ID
          "--batch-size", str(batch_size),  # ~ batch size
          "--batch-count", str(batch_count),  # ~ number of batches to run
          "--num-words", str(num_words),  # ~ number of words to request
          "--conf-delay", str(conf_delay),  # ~ confirmation delay
          "--cb-gas-limit", str(cb_gas_limit)]  # ~ callback gas limit
    return run_command(plan, cmd)

def get_load_test_results(plan, consumer_address):
    cmd = ["get-load-test-results", 
          "--consumer-address", consumer_address]  # ~ Load test contract address
    return run_command(plan, cmd)

# ─────────────────── VERIFICATION COMMANDS ───────────────────

def verify_beacon_randomness(plan, dkg_address, beacon_address, coordinator_address, height, conf_delay=1, search_window=200):
    cmd = ["verify-beacon-randomness",
          "--dkg-address", dkg_address,  # ~ DKG contract address
          "--beacon-address", beacon_address,  # ~ VRF beacon contract address
          "--coordinator-address", coordinator_address,  # ~ VRF coordinator contract address
          "--height", str(height),  # ~ block height of VRF beacon output
          "--conf-delay", str(conf_delay),  # ~ confirmation delay of VRF beacon output
          "--search-window", str(search_window)]  # ~ search space size for beacon transmission. Number of blocks after beacon height
    return run_command(plan, cmd)

# ─────────────────── UTILITY COMMANDS ───────────────────

def link_balance(plan, link_address):
    cmd = ["link-balance", 
          "--link-address", link_address]  # ~ link address
    return run_command(plan, cmd)

def get_balances(plan, addresses):
    cmd = ["get-balances", 
          "--addresses", addresses]  # ~ comma-separated list of addresses
    return run_command(plan, cmd)

# ─────────────────── OCR2VRF SETUP COMMANDS ───────────────────

def ocr2vrf_setup(plan):
    return run_command(plan, ["ocr2vrf-setup"])

def ocr2vrf_setup_infra_forwarder(plan):
    return run_command(plan, ["ocr2vrf-setup-infra-forwarder"])

def ocr2vrf_fund_nodes(plan):
    return run_command(plan, ["ocr2vrf-fund-nodes"])

def ocr2vrf_deploy_contracts(plan, key_id="aee00d81f822f882b6fe28489822f59ebb21ea95c0ae21d9f67c0239461148fc", 
                           link_address="", link_eth_feed="", wei_per_unit_link="6e16", 
                           beacon_period_blocks=3, max_cb_gas_limit=2500000, max_cb_args_length=320):
    """Deploy all OCR2VRF contracts and return the addresses as a dictionary"""
    
    cmd = ["ocr2vrf-deploy-contracts",
          "--key-id", key_id,
          "--link-address", link_address,
          "--link-eth-feed", link_eth_feed,
          "--wei-per-unit-link", wei_per_unit_link,
          "--beacon-period-blocks", str(beacon_period_blocks),
          "--max-cb-gas-limit", str(max_cb_gas_limit),
          "--max-cb-args-length", str(max_cb_args_length)]
    
    # Convert the command array to a shell command string
    cmd_str = "/usr/local/bin/ocr2vrf " + " ".join(cmd)
    
    # Use shell to execute with pipes
    result = plan.exec(
        service_name = GO_SERVICE_NAME,
        recipe = ExecRecipe(
            command = ["sh", "-c", cmd_str + " | grep -A 100 CONTRACT_ADDRESSES_JSON_BEGIN | grep -B 100 CONTRACT_ADDRESSES_JSON_END"],
            extract = {
                "dkg_address": "fromjson | .dkg",
                "vrf_coordinator_address": "fromjson | .vrf_coordinator",
                "vrf_beacon_address": "fromjson | .vrf_beacon",
                "link_token_address": "fromjson | .link_token",
                "link_eth_feed_address": "fromjson | .link_eth_feed"
            }
        )
    )
    
    # Return the extracted addresses
    addresses = {}
    if "dkg_address" in result.extraction and result.extraction["dkg_address"]:
        addresses["dkg_address"] = result.extraction["dkg_address"]
    if "vrf_coordinator_address" in result.extraction and result.extraction["vrf_coordinator_address"]:
        addresses["vrf_coordinator_address"] = result.extraction["vrf_coordinator_address"]
    if "vrf_beacon_address" in result.extraction and result.extraction["vrf_beacon_address"]:
        addresses["vrf_beacon_address"] = result.extraction["vrf_beacon_address"]
    if "link_token_address" in result.extraction and result.extraction["link_token_address"]:
        addresses["link_token_address"] = result.extraction["link_token_address"]
    if "link_eth_feed_address" in result.extraction and result.extraction["link_eth_feed_address"]:
        addresses["link_eth_feed_address"] = result.extraction["link_eth_feed_address"]
    
    return addresses

def cleanup(plan):
    plan.remove_service(GO_SERVICE_NAME) 