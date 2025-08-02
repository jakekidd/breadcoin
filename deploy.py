#!/usr/bin/env python3

import os
import json
import requests
import time
from web3 import Web3
from eth_account import Account
from dotenv import load_dotenv

# Load environment variables from .env file. Jeez, 2025 and python can't natively do this?
load_dotenv()

def verify_on_etherscan(contract_address, api_key, baker_address, chain_id=1):
    """Verify contract on Etherscan. This is good so everyone can see it and how great it is."""
    
    # Read source code.
    with open('src/BreadCoin.sol', 'r') as f:
        source_code = f.read()
    
    # Etherscan API endpoints. Mainnet or sepolia, depending on how you're feeling today.
    api_urls = {
        1: "https://api.etherscan.io/api",
        11155111: "https://api-sepolia.etherscan.io/api"
    }
    
    url = api_urls.get(chain_id, api_urls[1])
    
    # ABI encode the constructor argument (baker address)
    from eth_abi import encode
    constructor_args = encode(['address'], [baker_address]).hex()
    
    data = {
        'apikey': api_key,
        'module': 'contract',
        'action': 'verifysourcecode',
        'contractaddress': contract_address,
        'sourceCode': source_code,
        'codeformat': 'solidity-single-file',
        'contractname': 'BreadCoin',
        'compilerversion': 'v0.8.23+commit.f704f362',
        'optimizationUsed': '1',
        'runs': '200',
        'constructorArguements': constructor_args,
        'evmversion': 'paris',
        'licenseType': '3'  # MIT License
    }
    
    response = requests.post(url, data=data)
    result = response.json()
    
    if result['status'] == '1':
        print(f"Verification submitted! GUID: {result['result']}")
        return result['result']
    else:
        print(f"Verification failed: {result['message']}")
        return None

def deploy_breadcoin():
    # Load environment variables
    private_key = os.getenv('PRIVATE_KEY')
    infura_url = os.getenv('INFURA_URL')
    baker_address = os.getenv('BAKER')
    etherscan_api_key = os.getenv('ETHERSCAN_API_KEY')
    
    if not private_key or not infura_url or not baker_address:
        raise ValueError("Please set PRIVATE_KEY, INFURA_URL, and BAKER env vars. Be sure to do this somewhere safe. Check to make sure no hackers are standing directly behind you looking at your screen.")
    
    # Connect to the blockchains.
    w3 = Web3(Web3.HTTPProvider(infura_url))
    if not w3.is_connected():
        raise ConnectionError("Failed to connect to blockchain")
    
    # Load account.
    account = Account.from_key(private_key)
    
    # Load compiled contract (assumes you ran `forge build`).
    with open('out/BreadCoin.sol/BreadCoin.json', 'r') as f:
        contract_json = json.load(f)
    
    bytecode = contract_json['bytecode']['object']
    abi = contract_json['abi']
    
    # Create contract.
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    
    # Build deployment transaction.
    tx = contract.constructor(baker_address).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 2000000,
        'gasPrice': w3.eth.gas_price,
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
        print("Waiting 30 seconds before verification...")
        time.sleep(30)  # Wait for Etherscan to index the contract.
        chain_id = w3.eth.chain_id
        verify_on_etherscan(contract_address, etherscan_api_key, baker_address, chain_id)
    
    return contract_address

if __name__ == "__main__":
    deploy_breadcoin() 