# Service types
SERVICE_TYPE = struct(
    chainlink="chainlink",
    postgres="postgres",
)

# VRF types and settings
VRF_TYPE = struct(
    MPC = "mpc",
    VRFV2PLUS = "vrfv2plus",
)

DEFAULT_LINK_TOKEN_ADDRESS = ""
DEFAULT_LINK_NATIVE_TOKEN_FEED_ADDRESS = ""

# Default images
DEFAULT_CHAINLINK_IMAGE_VERSION = "2.23.0"

DEFAULT_CHAINLINK_VRF_TYPE = VRF_TYPE.VRFV2PLUS

# Default VRF settings
DEFAULT_MPC_VRF_SETTINGS = {
    "nodes_number": 6,
    "faulty_oracles": 1,
}