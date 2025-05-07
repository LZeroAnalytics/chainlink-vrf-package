# These are the only allowed fields in the config.yaml
NETWORK_CONFIG_PARAMS = [
    "type",
    "rpc",
    "ws",
    "chain_id",
    "private_key",
    "faucet",
]

VRF_CONFIG_PARAMS = [
    "link_token_address",
    "link_native_token_feed_address",
    "vrf_type",
    "mpc_vrf_settings"
]

MPC_VRF_SETTINGS_PARAMS = [
    "nodes_number",
    "faulty_oracles",
]

def sanity_check(plan, input_args):
    """Validate input arguments for the VRF package"""
    # Check network config fields
    if "network" in input_args:
        validate_params(plan, input_args["network"], "network", NETWORK_CONFIG_PARAMS)
        
    # Check vrf config fields
    if "vrf" in input_args:
        validate_params(plan, input_args["vrf"], "vrf", VRF_CONFIG_PARAMS)
        
        # Check mpc_vrf_settings if present
        if "mpc_vrf_settings" in input_args["vrf"]:
            validate_params(plan, input_args["vrf"]["mpc_vrf_settings"], "vrf.mpc_vrf_settings", MPC_VRF_SETTINGS_PARAMS)
              
    plan.print("VRF package sanity check passed")

def validate_params(plan, config, category, allowed_params):
    """Validate parameters against allowed list"""
    for param in config:
        if param not in allowed_params:
            fail(
                "Invalid parameter '{0}' for {1}. Allowed fields: {2}".format(
                    param, category, allowed_params
                )
            ) 