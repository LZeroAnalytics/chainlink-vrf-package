constants = import_module("./constants.star")
sanity_check = import_module("./sanity_check.star")

def input_parser(plan, input_args):
    """Parse and validate input arguments for the VRF package"""
    
    # Run sanity check first
    sanity_check.sanity_check(plan, input_args)
    
    # Get default configuration
    result = default_input_args()
    
    # Parse network config
    if "network" in input_args:
        for key, value in input_args["network"].items():
            result["network"][key] = value
            
    # Parse vrf config
    if "vrf" in input_args:
        for key, value in input_args["vrf"].items():
            result["vrf"][key] = value
    
    # Validate configuration
    validate_config(result)

    # Return as struct for immutability with proper extension of network config
    return struct(
        network = struct(
            type = result["network"]["type"],
            rpc = result["network"]["rpc"],
            ws = result["network"]["ws"],
            chain_id = result["network"]["chain_id"],
            private_key = result["network"]["private_key"],
            faucet = result["network"]["faucet"],
        ),
        chainlink = struct(
            vrf_type = result["vrf"]["vrf_type"],
            link_token_address = result["vrf"]["link_token_address"],
            link_native_token_feed_address = result["vrf"]["link_native_token_feed_address"],
            mpc_vrf_settings = struct(
                nodes_number = result["vrf"]["mpc_vrf_settings"]["nodes_number"],
                faulty_oracles = result["vrf"]["mpc_vrf_settings"]["faulty_oracles"],
            ),
        ),
        # Create network config compatible with chainlink package
        chainlink_network_config = {
            "type": result["network"]["type"],
            "rpc": result["network"]["rpc"],
            "ws": result["network"]["ws"],
            "chain_id": result["network"]["chain_id"],
            "private_key": result["network"]["private_key"],
            "faucet": result["network"]["faucet"],
        }
    )

def default_input_args():
    """Return default configuration values"""
    return {
        "network": {
            "type": "",
            "rpc": "",
            "ws": "",
            "chain_id": "",
            "private_key": "",
            "faucet": "",
        },
        "vrf": {
            "link_token_address": constants.DEFAULT_LINK_TOKEN_ADDRESS,
            "link_native_token_feed_address": constants.DEFAULT_LINK_NATIVE_TOKEN_FEED_ADDRESS,
            "vrf_type": constants.DEFAULT_CHAINLINK_VRF_TYPE,
            "mpc_vrf_settings": constants.DEFAULT_MPC_VRF_SETTINGS,
        }
    }

def validate_config(config):
    """Validate the configuration"""
    # Validate Network config
    if not config["network"]["type"]:
        fail("network.type is required")
    if not config["network"]["rpc"]:
        fail("network.rpc is required")
    if not config["network"]["ws"]:
        fail("network.ws is required")
    if not config["network"]["chain_id"]:
        fail("network.chain_id is required")
    if not config["network"]["private_key"]:
        fail("network.private_key is required")
    if not config["network"]["faucet"]:
        fail("network.faucet is required")
        
    # Validate VRF-specific config
    if not config["vrf"]["link_token_address"]:
        fail("vrf.link_token_address is required")
    if not config["vrf"]["link_native_token_feed_address"]:
        fail("vrf.link_native_token_feed_address is required")
    if config["vrf"]["vrf_type"] not in [constants.VRF_TYPE.MPC, constants.VRF_TYPE.VRFV2PLUS]:
        fail("vrf.vrf_type must be either '{0}' or '{1}'".format(constants.VRF_TYPE.MPC, constants.VRF_TYPE.VRFV2PLUS))
        
    # Validate VRF settings based on type
    if config["vrf"]["vrf_type"] == constants.VRF_TYPE.MPC:
        if not config["vrf"]["mpc_vrf_settings"]["nodes_number"] > 5:
            fail("vrf.mpc_vrf_settings.nodes_number must be at least 6 for MPC VRF")
        if not config["vrf"]["mpc_vrf_settings"]["faulty_oracles"] > 0:
            fail("vrf.mpc_vrf_settings.faulty_oracles must be at least 1 for MPC VRF")

