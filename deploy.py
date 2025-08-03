#!/usr/bin/env python3
# This is how you know this is some real shit. Imports from the future? Like, damn
from __future__ import annotations

import os
import json
import time
import subprocess
import shutil
import requests
from web3 import Web3
from eth_account import Account
from dotenv import load_dotenv

# Load environment variables from .env file. Jeez, 2025 and python can't natively do this?
load_dotenv()

def _etherscan_base_url(chain_id: int) -> str:
    # Etherscan API endpoints. Mainnet or sepolia, depending on how you're feeling today.
    return {
        1: "https://api.etherscan.io/api",
        11155111: "https://api-sepolia.etherscan.io/api",
    }.get(chain_id, "https://api.etherscan.io/api")

def _flatten_source(src_path: str, out_path: str) -> str:
    """
    Try to flatten with Foundry. If forge isn't installed, fall back to returning the original file.
    (Etherscan hates unresolved imports like '@openzeppelin/...', so flattening avoids tears...)
    """
    forge = shutil.which("forge")
    if forge:
        try:
            subprocess.run(
                [forge, "flatten", src_path],
                check=True,
                stdout=open(out_path, "w"),
                stderr=subprocess.PIPE,
                text=True,
            )
            return out_path
        except subprocess.CalledProcessError as e:
            print("Flatten failed (forge). Using unflattened source:", e.stderr[:200] or e)
    else:
        print("forge not found — verifying with unflattened source (may fail if you import OZ).")
    return src_path

def _read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def _derive_compiler_and_opts(contract_json: dict) -> tuple[str, str, str]:
    """
    Pull compiler version, optimizer, runs from Foundry artifact if present,
    else provide reasonable defaults that match your current settings.
    """
    # Defaults that I personally like a lot, you can change if you want
    compiler = "v0.8.30+commit.73712a01"
    optimization_used = "1"
    runs = "200"

    # Damn, now this is some real code.
    try:
        md = contract_json.get("metadata")
        if isinstance(md, str):
            meta = json.loads(md)
        elif isinstance(md, dict):
            meta = md
        else:
            meta = None

        if meta:
            v = meta.get("compiler", {}).get("version")
            if v:
                # Etherscan wants the exact solc build tag string (prefixed with 'v')
                compiler = ("v" + v) if not v.startswith("v") else v
            opt = meta.get("settings", {}).get("optimizer", {})
            if "enabled" in opt:
                optimization_used = "1" if opt["enabled"] else "0"
            if "runs" in opt:
                runs = str(opt["runs"])
    except Exception:
        pass

    return compiler, optimization_used, runs

def verify_on_etherscan(contract_address: str, api_key: str, baker_address: str, chain_id: int, artifact_path: str = "out/BreadCoin.sol/BreadCoin.json") -> str | None:
    """Verify contract on Etherscan. This is good so everyone can see it and how great it is."""

    # Prefer flattened source to avoid '@openzeppelin/...' not found errors.
    flattened_path = _flatten_source("src/BreadCoin.sol", "BreadCoinFlat.sol")
    source_code = _read_text(flattened_path)

    # Load artifact to derive ABI/metadata settings and guard against mismatches.
    with open(artifact_path, "r", encoding="utf-8") as f:
        contract_json = json.load(f)

    compiler, optimization_used, runs = _derive_compiler_and_opts(contract_json)

    # ABI encode the constructor argument (baker address)
    from eth_abi import encode
    constructor_args = encode(["address"], [baker_address]).hex()  # no '0x' prefix per Etherscan

    url = _etherscan_base_url(chain_id)

    data = {
        "apikey": api_key,
        "module": "contract",
        "action": "verifysourcecode",
        "contractaddress": contract_address,
        "sourceCode": source_code,
        "codeformat": "solidity-single-file",
        "contractname": f"{os.path.basename(flattened_path)}:BreadCoin",
        "compilerversion": compiler,
        "optimizationUsed": optimization_used,
        "runs": runs,
        "constructorArguements": constructor_args,  # yes, Etherscan spells it this way
        "evmversion": "paris",
        "licenseType": "3",  # MIT License
    }

    resp = requests.post(url, data=data, timeout=60)
    result = resp.json()
    status = result.get("status")
    message = result.get("message", "")
    outcome = result.get("result", "")

    if status == "1":
        guid = outcome
        print(f"Verification submitted! GUID: {guid}")
        # Poll for completion because we're nosy.
        return _poll_etherscan_guid(url, api_key, guid)
    else:
        print(f"Verification submit failed: {message} — {outcome}")
        # Helpful hint if OZ imports are the reason:
        if "not found" in outcome.lower() or "import" in outcome.lower():
            print("Hint: Ensure you flattened the contract so '@openzeppelin/...' imports are inline.")
        return None

def _poll_etherscan_guid(api_url: str, api_key: str, guid: str, timeout_sec: int = 180, interval_sec: int = 5) -> str | None:
    """
    Poll Etherscan for verification status. Returns the final result message (and prints it),
    or None if we gave up. Like a crockpot: set it, forget it, check occasionally.
    """
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        time.sleep(interval_sec)
        q = {
            "apikey": api_key,
            "module": "contract",
            "action": "checkverifystatus",
            "guid": guid,
        }
        r = requests.get(api_url, params=q, timeout=30).json()
        status = r.get("status")
        msg = r.get("message", "")
        res = r.get("result", "")

        if status == "1" and "Pass" in res:
            print("Etherscan says: Verification successful! Congrats! Yay! You really exist")
            return "success"
        elif status == "0" and "Pending" in res:
            print("Etherscan says: Still pending...")
            continue
        elif status == "0" and "Unable to verify" in res:
            print(f"Etherscan says: {res}")
            return None
        else:
            # Unknown but maybe success phrasing varies; print and keep trying a bit more.
            print(f"Status: {status} | Message: {msg} | Result: {res}")

    print("Gave up waiting on Etherscan. Check manually later with your GUID.")
    return None

def deploy_breadcoin():
    # Load environment variables
    private_key = os.getenv("PRIVATE_KEY")
    infura_url = os.getenv("INFURA_URL")
    baker_address = os.getenv("BAKER")
    etherscan_api_key = os.getenv("ETHERSCAN_API_KEY")

    if not private_key or not infura_url or not baker_address:
        raise ValueError("Please set PRIVATE_KEY, INFURA_URL, and BAKER env vars. Be sure to do this somewhere safe. Check to make sure no hackers are standing directly behind you looking at your screen.")

    # Connect to the blockchains.
    w3 = Web3(Web3.HTTPProvider(infura_url))
    if not w3.is_connected():
        raise ConnectionError("Failed to connect to blockchain")

    # Load account.
    account = Account.from_key(private_key)
    balance_wei = w3.eth.get_balance(account.address)
    print(f"Deployer address: {account.address}")
    print(f"Deployer balance: {balance_wei / 10**18:.4f} ETH")

    if balance_wei == 0:
        print(f"Deployer address {account.address} has 0 ETH!")
        print("Send some ETH to this address to pay for gas. But only if you trust them. I mean, it is the private key from your .env file. But do you trust yourself from earlier in time?")
        return None

    # Load compiled contract (assumes you ran `forge build`).
    with open("out/BreadCoin.sol/BreadCoin.json", "r", encoding="utf-8") as f:
        contract_json = json.load(f)

    bytecode = contract_json["bytecode"]["object"]
    abi = contract_json["abi"]

    # Create contract.
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)

    # Build deployment transaction.
    chain_id = w3.eth.chain_id
    nonce = w3.eth.get_transaction_count(account.address)

    # Estimate gas because guessing is for fortune tellers.
    try:
        gas_estimate = contract.constructor(baker_address).estimate_gas({"from": account.address})
    except Exception:
        gas_estimate = 2_000_000  # "If it compiles, ship it" — you, five minutes ago.

    tx = contract.constructor(baker_address).build_transaction({
        "from": account.address,
        "nonce": nonce,
        "chainId": chain_id,
        "gas": int(gas_estimate * 1.2),  # small safety margin
        "gasPrice": w3.eth.gas_price,
    })

    # Sign and send transaction.
    signed_tx = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)

    print(f"Transaction hash: {tx_hash.hex()}")

    # Wait for confirmation.
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    contract_address = receipt.contractAddress

    print(f"BreadCoin deployed at: {contract_address}")
    print(f"Gas used: {receipt.gasUsed}")

    # Verify on Etherscan if API key provided.
    if etherscan_api_key:
        print("Waiting 45 seconds before verification...")
        time.sleep(45)  # Wait for Etherscan to index the contract.
        verify_on_etherscan(contract_address, etherscan_api_key, baker_address, chain_id)
    else:
        print("Skipping Etherscan verification (no ETHERSCAN_API_KEY set).")

    return contract_address

if __name__ == "__main__":
    deploy_breadcoin()
