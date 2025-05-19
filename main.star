hardhat_pkg = import_module("github.com/LZeroAnalytics/hardhat-package/main.star")
chainlink_pkg = import_module("github.com/LZeroAnalytics/chainlink-node-package/main.star")
input_parser = import_module("./src/package_io/input_parser.star")
constants = import_module("./src/package_io/constants.star")
ocr2vrf_cli = import_module("./src/ocr2vrf/ocr2vrf.star")

def run(plan, args = {}):
    config = input_parser.input_parser(plan, args)

    result = setup_mpc_vrf_network(plan, config)
    
    return struct(
        contracts_addresses = result.contracts_addresses,
        chainlink_nodes = result.chainlink_nodes
    )


def setup_mpc_vrf_network(plan, config):
    # Create database and configs for all chainlink nodes in parallel
    chainlink_node_configs = []
    for i in range(config.chainlink.mpc_vrf_settings.nodes_number):
        chainlink_node_configs.append(struct(
            node_name = "chainlink-node-mpc-vrf-" + str(i),
            image_version = "2.14.0"
        ))
    
    # Pass the chainlink nodes configuration to the chainlink package
    all_nodes = chainlink_pkg.run(plan, args = { 
        "network": {
            "rpc": config.network.rpc,
            "ws": config.network.ws,
            "chain_id": config.network.chain_id
        },
        "chainlink_nodes": chainlink_node_configs
    })

    vrf_nodes_setups = []
    # KIP: would be nice to be able to do this in parallel (but also neeed to get return variables)
    for i in range(config.chainlink.mpc_vrf_settings.nodes_number):
        vrf_setup = setup_chainlink_node_for_ocr2vrf(plan, "chainlink-node-mpc-vrf-" + str(i), config.network.faucet)
        vrf_nodes_setups.append(vrf_setup)

    # Deploy contracts using Hardhat
    contracts_addresses = deploy_mpc_vrf_contracts(
        plan, 
        config.network.private_key,
        config.network.rpc,
        config.chainlink.link_token_address,
        config.chainlink.link_native_token_feed_address,
        vrf_nodes_setups[0].dkg_encr_key,
        config.network.type,
        config.network.chain_id
    )

    plan.print(contracts_addresses)

    setup_mpc_vrf_contracts(plan, vrf_nodes_setups, contracts_addresses.dkg, contracts_addresses.vrf_beacon, config.chainlink.mpc_vrf_settings.faulty_oracles, config.network)

    chainlink_pkg.create_bootstrap_job(
        plan,
        contracts_addresses.dkg,
        config.network.chain_id,
        "chainlink-node-mpc-vrf-0"
    )

    # Create DKG jobs for all nodes except the first one (which is bootstrap)
    for i in range(1, config.chainlink.mpc_vrf_settings.nodes_number):
        chainlink_pkg.dkg.create_dkg_job(
            plan,
            str(i),
            contracts_addresses.dkg,
            vrf_nodes_setups[i].ocr_key_bundle_id,
            vrf_nodes_setups[0].p2p_peer_id,
            all_nodes["chainlink-node-mpc-vrf-0"].ip_address,
            all_nodes["chainlink-node-mpc-vrf-0"].ports["p2p"].number,
            vrf_nodes_setups[i].eth_address,
            vrf_nodes_setups[i].dkg_encr_key,
            vrf_nodes_setups[i].dkg_sign_key,
            vrf_nodes_setups[0].dkg_encr_key,
            config.network.chain_id,
            "chainlink-node-mpc-vrf-" + str(i)
        )

        chainlink_pkg.ocr2vrf.create_ocr2vrf_job(
            plan,
            "VRF-Bloctopus-Default-Chain-Coordinator-Job",
            contracts_addresses.vrf_beacon,
            vrf_nodes_setups[i].ocr_key_bundle_id,
            vrf_nodes_setups[i].eth_address,
            vrf_nodes_setups[0].p2p_peer_id,
            all_nodes["chainlink-node-mpc-vrf-0"].ip_address,
            all_nodes["chainlink-node-mpc-vrf-0"].ports["p2p"].number,
            config.network.chain_id,
            vrf_nodes_setups[i].dkg_encr_key,
            vrf_nodes_setups[i].dkg_sign_key,
            vrf_nodes_setups[0].dkg_encr_key,
            contracts_addresses.dkg,
            contracts_addresses.coordinator,
            config.chainlink.link_native_token_feed_address,
            "chainlink-node-mpc-vrf-" + str(i)
        )
    
    return struct(
        contracts_addresses = contracts_addresses,
        chainlink_nodes = all_nodes
    )


def deploy_mpc_vrf_contracts(plan, private_key, rpc_url, link_token_address, link_native_token_feed_address, key_id, network_type="ethereum", chain_id="3151908"):
    """Deploy contracts using Hardhat"""
    #TODO deploy link token and link eth feed contract too if not set 
    hardhat = hardhat_pkg.init(
        plan, 
        "github.com/LZeroAnalytics/hardhat-vrf-contracts",
        env_vars = {
            "RPC_URL": rpc_url,
            "PRIVATE_KEY": private_key,
            "LINK_TOKEN_ADDRESS": link_token_address,
            "LINK_NATIVE_TOKEN_FEED_ADDRESS": link_native_token_feed_address,
            "DKG_KEY_ID": key_id,
            "NETWORK_TYPE": network_type,
            "CHAIN_ID": chain_id
        }
    )

    hardhat_pkg.compile(plan)
    
    # Deploy coordinator and get addresses
    result = hardhat_pkg.script(
        plan = plan,
        script = "scripts/ocr2vrf/deploy-setup-contracts.ts",
        network = "bloctopus",
        return_keys = ["vrfCoordinatorMPC", "dkg", "vrfBeacon"]
    )

    return struct(
        coordinator = result["extract.vrfCoordinatorMPC"],
        dkg = result["extract.dkg"],
        vrf_beacon = result["extract.vrfBeacon"]
    )

def setup_mpc_vrf_contracts(plan, vrf_nodes_setups, dkg_address, vrf_beacon_addr, faulty_oracles, network_config):
    ocr2vrf_cli.init(
        plan, 
        network_config.private_key,
        network_config.rpc,
        network_config.chain_id
    )

    key_id = vrf_nodes_setups[0].dkg_encr_key
    onchain_pub_keys = ",".join([node.ocr_keys.on_chain_key for node in vrf_nodes_setups])
    offchain_pub_keys = ",".join([node.ocr_keys.off_chain_key for node in vrf_nodes_setups])
    config_pub_keys = ",".join([node.ocr_keys.config_key for node in vrf_nodes_setups])
    peer_ids = ",".join([node.p2p_peer_id for node in vrf_nodes_setups])
    transmitters = ",".join([node.eth_address for node in vrf_nodes_setups])
    dkg_encryption_pub_keys = ",".join([node.dkg_encr_key for node in vrf_nodes_setups])
    dkg_signing_pub_keys = ",".join([node.dkg_sign_key for node in vrf_nodes_setups])
    schedule="1,1,1,1,1"

    ocr2vrf_cli.dkg_set_config(plan, dkg_address, key_id, onchain_pub_keys, offchain_pub_keys, config_pub_keys, peer_ids, transmitters, dkg_encryption_pub_keys, dkg_signing_pub_keys, schedule, faulty_oracles)

    conf_delays="1,2,3,4,5,6,7,8"
    ocr2vrf_cli.beacon_set_config(plan, vrf_beacon_addr, conf_delays, onchain_pub_keys, offchain_pub_keys, config_pub_keys, peer_ids, transmitters, schedule, f=1)

    # Set payees for VRF beacon - each node gets paid to its own ETH address
    payees = ",".join([node.eth_address for node in vrf_nodes_setups])
    ocr2vrf_cli.beacon_set_payees(plan, vrf_beacon_addr, transmitters, payees)

def fund_eth_key(plan, eth_key, faucet_url):
    # Use run_sh which is designed for one-time tasks like HTTP requests
    result = plan.run_sh(
        name = "fund-link-node-eth-wallet",
        image = "curlimages/curl:latest",
        run = "curl -X POST " + faucet_url + "/fund -H 'Content-Type: application/json' -d '{\"address\":\"" + eth_key + "\",\"amount\":0.1}'"
    )
    
    # No need to create/remove services
    return result.code

def setup_chainlink_node_for_ocr2vrf(plan, node_name, faucet_url):
    p2p_peer_id = chainlink_pkg.get_p2p_peer_id(plan, node_name)
    eth_address = chainlink_pkg.get_eth_key(plan, node_name)

    fund_eth_key(plan, eth_address, faucet_url)

    dkg_encr_key = chainlink_pkg.dkg.create_dkg_encr_key(plan, node_name)
    dkg_sign_key = chainlink_pkg.dkg.create_dkg_sign_key(plan, node_name)
    ocr_key_bundle_id = chainlink_pkg.get_ocr_key_bundle_id(plan, node_name)
    ocr_keys = chainlink_pkg.get_ocr_key(plan, node_name)

    return struct(
        p2p_peer_id = p2p_peer_id,
        eth_address = eth_address,
        dkg_encr_key = dkg_encr_key,
        dkg_sign_key = dkg_sign_key,
        ocr_key_bundle_id = ocr_key_bundle_id,
        ocr_keys = ocr_keys
    )