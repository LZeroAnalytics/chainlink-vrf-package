package helpers

import (
	"context"
	"crypto/ecdsa"
	"encoding/hex"
	"flag"
	"fmt"
	"math/big"
	"os"
	"strconv"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"

	"github.com/smartcontractkit/chainlink/v2/core/gethwrappers/generated/link_token_interface"
	"github.com/smartcontractkit/chainlink/v2/core/gethwrappers/generated/mock_v3_aggregator_contract"
)

type Environment struct {
	Owner   *bind.TransactOpts
	Ec      *ethclient.Client
	Jc      *rpc.Client
	ChainID int64
}

// PanicErr panics if error the given error is non-nil.
func PanicErr(err error) {
	if err != nil {
		panic(err)
	}
}

// ParseArgs parses arguments and ensures required args are set.
func ParseArgs(flagSet *flag.FlagSet, args []string, requiredArgs ...string) {
	PanicErr(flagSet.Parse(args))
	seen := map[string]bool{}
	argValues := map[string]string{}
	flagSet.Visit(func(f *flag.Flag) {
		seen[f.Name] = true
		argValues[f.Name] = f.Value.String()
	})
	for _, req := range requiredArgs {
		if !seen[req] {
			panic(fmt.Errorf("missing required -%s argument/flag", req))
		}
	}
}

// SetupEnv returns an Environment object populated from environment variables.
// If overrideNonce is set to true, the nonce will be set to what is returned
// by NonceAt (rather than the typical PendingNonceAt).
func SetupEnv(overrideNonce bool) Environment {
	ethURL, set := os.LookupEnv("ETH_URL")
	if !set {
		panic("need eth url")
	}

	chainIDEnv, set := os.LookupEnv("ETH_CHAIN_ID")
	if !set {
		panic("need chain ID")
	}

	accountKey, set := os.LookupEnv("ACCOUNT_KEY")
	if !set {
		panic("need account key")
	}

	ec, err := ethclient.Dial(ethURL)
	PanicErr(err)

	jsonRPCClient, err := rpc.Dial(ethURL)
	PanicErr(err)

	chainID, err := strconv.ParseInt(chainIDEnv, 10, 64)
	PanicErr(err)

	// Owner key. Make sure it has eth
	b, err := hex.DecodeString(accountKey)
	PanicErr(err)
	d := new(big.Int).SetBytes(b)

	pkX, pkY := crypto.S256().ScalarBaseMult(d.Bytes())
	privateKey := ecdsa.PrivateKey{
		PublicKey: ecdsa.PublicKey{
			Curve: crypto.S256(),
			X:     pkX,
			Y:     pkY,
		},
		D: d,
	}
	owner, err := bind.NewKeyedTransactorWithChainID(&privateKey, big.NewInt(chainID))
	PanicErr(err)
	// Explicitly set gas price to ensure non-eip 1559
	gp, err := ec.SuggestGasPrice(context.Background())
	PanicErr(err)
	fmt.Println("Suggested Gas Price:", gp, "wei")
	owner.GasPrice = gp
	gasLimit, set := os.LookupEnv("GAS_LIMIT")
	if set {
		parsedGasLimit, err := strconv.ParseUint(gasLimit, 10, 64)
		if err != nil {
			panic(fmt.Sprintf("Failure while parsing GAS_LIMIT: %s", gasLimit))
		}
		owner.GasLimit = parsedGasLimit
	}

	if overrideNonce {
		block, err := ec.BlockNumber(context.Background())
		PanicErr(err)

		nonce, err := ec.NonceAt(context.Background(), owner.From, big.NewInt(int64(block)))
		PanicErr(err)

		owner.Nonce = big.NewInt(int64(nonce))
	}
	owner.GasPrice = gp.Mul(gp, big.NewInt(2))
	fmt.Println("Modified Gas Price that will be set:", owner.GasPrice, "wei")
	// the execution environment for the scripts
	return Environment{
		Owner:   owner,
		Ec:      ec,
		Jc:      jsonRPCClient,
		ChainID: chainID,
	}
}

// ConfirmTXMined waits for tx to be mined on the blockchain and returns confirmation details
func ConfirmTXMined(context context.Context, client *ethclient.Client, transaction *types.Transaction, chainID int64, txInfo ...string) (receipt *types.Receipt) {
	var err error
	txHash := transaction.Hash()

	if len(txInfo) > 0 {
		fmt.Printf("Waiting for transaction %s to be mined for %s\n", txHash.String(), strings.Join(txInfo, ","))
	} else {
		fmt.Printf("Waiting for transaction %s to be mined\n", txHash.String())
	}

	receipt, err = bind.WaitMined(context, client, transaction)
	PanicErr(err)

	fmt.Printf("Transaction mined in block %d\n", receipt.BlockNumber.Uint64())
	return
}

// ConfirmContractDeployed waits for contract deployment transaction to be mined and returns contract address
func ConfirmContractDeployed(context context.Context, client *ethclient.Client, transaction *types.Transaction, chainID int64) (address common.Address) {
	contractDeployReceipt := ConfirmTXMined(context, client, transaction, chainID, "Contract deployment")
	return contractDeployReceipt.ContractAddress
}

// ParseIntSlice converts comma-separated string of integers into a slice of integers
func ParseIntSlice(arg string) (ret []int) {
	for _, s := range strings.Split(arg, ",") {
		if s == "" {
			continue
		}
		i, err := strconv.Atoi(strings.TrimSpace(s))
		PanicErr(err)
		ret = append(ret, i)
	}
	return
}

// ParseAddressSlice converts comma-separated string of addresses into a slice of addresses
func ParseAddressSlice(arg string) (ret []common.Address) {
	for _, s := range strings.Split(arg, ",") {
		if s == "" {
			continue
		}
		ret = append(ret, common.HexToAddress(strings.TrimSpace(s)))
	}
	return
}

// DeployLinkToken deploys a LINK token contract and returns its address
func DeployLinkToken(e Environment) common.Address {
	_, tx, _, err := link_token_interface.DeployLinkToken(e.Owner, e.Ec)
	PanicErr(err)
	return ConfirmContractDeployed(context.Background(), e.Ec, tx, e.ChainID)
}

// DeployLinkEthFeed deploys a LINK/ETH price feed and returns its address
func DeployLinkEthFeed(e Environment, linkAddress string, weiPerUnitLink *big.Int) common.Address {
	_, tx, _, err :=
		mock_v3_aggregator_contract.DeployMockV3AggregatorContract(
			e.Owner, e.Ec, 18, weiPerUnitLink)
	PanicErr(err)
	return ConfirmContractDeployed(context.Background(), e.Ec, tx, e.ChainID)
}

// FundNodes sends ETH to a list of node addresses
func FundNodes(e Environment, transmitters []string, fundingAmount *big.Int) {
	for _, t := range transmitters {
		FundNode(e, t, fundingAmount)
	}
}

// FundNode sends ETH to a node address
func FundNode(e Environment, address string, fundingAmount *big.Int) {
	toAddress := common.HexToAddress(address)
	balanceToAddress, err := e.Ec.BalanceAt(context.Background(), toAddress, nil)
	PanicErr(err)
	if balanceToAddress.Cmp(fundingAmount) >= 0 {
		fmt.Println("Address", address, "already has", balanceToAddress, "wei")
		return
	}
	nonce, err := e.Ec.PendingNonceAt(context.Background(), e.Owner.From)
	PanicErr(err)

	gasPrice, err := e.Ec.SuggestGasPrice(context.Background())
	PanicErr(err)

	tx := types.NewTransaction(
		nonce,
		toAddress,
		fundingAmount,
		uint64(21000),
		gasPrice,
		nil)

	signedTx, err := e.Owner.Signer(e.Owner.From, tx)
	PanicErr(err)

	err = e.Ec.SendTransaction(context.Background(), signedTx)
	PanicErr(err)

	fmt.Println("Funded", address, "with", fundingAmount, "wei")
}
