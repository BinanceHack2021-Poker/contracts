import HDWalletProvider from "@truffle/hdwallet-provider"
import Web3 from "web3"
import axios from "axios"

import ethJSUtil from 'ethereumjs-util'

import leftPad from 'left-pad'

import BN from 'bn.js'
//import call from "remix"
//import { erc721Abi } from "./contracts/raribleTransferContractAbi.js"

import { createRaribleSdk } from "@rarible/protocol-ethereum-sdk"

import { toAddress } from "@rarible/types"
import { toBigNumber } from "@rarible/types"
import { Web3Ethereum } from "@rarible/web3-ethereum"

import keccak256 from "keccak256"

import FormData from "form-data"; // a nodejs module.
global.FormData = FormData; // hack for nodejs;

import fetchApi from "node-fetch"; // a nodejs module.
global.window = {
    fetch: fetchApi,
}
//global.window = {fetch: {bind: }}

// DO NOT PUSH PRIVATE KEYS IN PUBLIC REPO!
const config = {
	mainnetRpc: "https://mainnet.infura.io/v3/84653a332a3f4e70b1a46aaea97f0435",
 	rinkebyRpc: "https://rinkeby.infura.io/v3/84653a332a3f4e70b1a46aaea97f0435",
 	rinkeby: "rinkeby"
}


export async function SignMessage(body) {
    const maker = new HDWalletProvider(body.private_ext, config.rinkebyRpc)
    const web3 = new Web3(maker)
    signMessageImpl(web3, body.msg)
}

export async function parseCardsCombinationFromSignature(web3, _r, _s, _v) {
    _r = "0x" + _r
    _s = "0x" + _s
    _v = "0x" + _v
    console.log("rsv: ", _r, _s, _v)
//    r = web3.utils.toDecimal(_r)
    const r = new web3.utils.BN(_r)
    const s = new web3.utils.BN(_s)
    const v = new web3.utils.BN(_v)
    console.log("r", r, s, v)
//    s = web3.utils.toDecimal(_s)
//    v = web3.utils.toDecimal(_v)
    console.log(v , _v, r, _r, s, _s);
    var seed = 3 * s + 5 * r + 7 * v;
    var cards = [];
    for(let i =0; i < 5; ++i) {
        cards.push(seed % 52);
        seed = 31 * seed + 13;
    }
    console.log(cards);
    return cards;
}

export async function hexToBytes(hex) {
// hex = "0x..."
    for (var bytes = [], c = 2; c < hex.length; c += 2)
    bytes.push(parseInt(hex.substr(c, 2), 16));
    return bytes;
}

export async function signMessageImpl(web3, msg) {
    const hash = web3.utils.soliditySha3(msg);
    const accounts = await web3.eth.getAccounts()
    const signature = await web3.eth.personal.sign(hash, accounts[0], function () { console.log("Signed"); });
    parseCardsCombinationFromSignature(
        web3,
        signature.slice(2, 32 * 2 + 2),
        signature.slice(32 * 2 + 2, 64 * 2 + 2),
        signature.slice(64 * 2 + 2, 65 *2 + 2));
//    console.log('0x' + personalMsg.toString('hex'), signedData)
    console.log({"hash": hash, "signature": signature})
    return {"hash": hash, "signature": signature}
}

export async function Deploy(body) {
    const maker = new HDWalletProvider(body.private_ext, config.rinkebyRpc)
    const web3 = new Web3(maker)
    return deployImpl(web3)
}

import fs from "fs"

export async function deployImpl(web3) {
    try {
        console.log('Running deployWithWeb3 script...')

        const contractName = 'ChainHoldem' // Change this for other contract
        const constructorArgs = ['10000000000000000']    // Put constructor args (if any) here for your contract - comission - 0.01 eth

        // Note that the script needs the ABI which is generated from the compilation artifact.
        // Make sure contract is compiled and artifacts are generated

        const artifactsPath = `/usr/src/app/src/contracts/artifacts/${contractName}.json` // Change this for different path

        const content = await fs.readFileSync(artifactsPath, 'utf8');


        const metadata = await JSON.parse(content)
        const accounts = await web3.eth.getAccounts()

        let contract = new web3.eth.Contract(metadata.abi)

        contract = contract.deploy({
            data: metadata.data.bytecode.object,
            arguments: constructorArgs
        })

        const newContractInstance = await contract.send({
            from: accounts[0],
            gas: 1500000,
            gasPrice: '30000000000'
        })
        console.log('Contract deployed at address: ', newContractInstance.options.address)
        return newContractInstance.options.address
    } catch (e) {
        console.log(e.message)
    }
}


export async function CallMethod(body) {
    const maker = new HDWalletProvider(body.private_ext, config.rinkebyRpc)
    const web3 = new Web3(maker)
    callMethodImpl(web3, body)
}

export async function callMethodImpl(web3, body) {
//    try {
        const contractName = 'ChainHoldem' // Change this for other contract
        const constructorArgs = []    // Put constructor args (if any) here for your contract

        // Note that the script needs the ABI which is generated from the compilation artifact.
        // Make sure contract is compiled and artifacts are generated

        const artifactsPath = `/usr/src/app/src/contracts/artifacts/${contractName}.json` // Change this for different path

        const content = fs.readFileSync(artifactsPath, 'utf8');

        const metadata = JSON.parse(content)
        const accounts = await web3.eth.getAccounts()

        let contract = new web3.eth.Contract(metadata.abi, body.contract_address)

        console.log(body.args_json)
        let method = await buildMethod(web3, contract, body.method, body.args_json)
//        console.log(method)
        const tx = await method.send({
            from: accounts[0],
            gas: 1500000,
            gasPrice: '30000000000'
        }).then((result) => {
            }, (error) => {
        console.log(error);
        });
        console.log("tx: ", tx)
//    } catch (e) {
//        console.log(e.message)
//    }
}

export async function makeSignature(web3, msg) {
    const hash = web3.utils.sha3(msg);
    const accounts = await web3.eth.getAccounts()
    return web3.eth.personal.sign(hash, accounts[0], function () { console.log("Signed"); });
}

export async function buildMethod(web3, contract, method, args) {
    if (method == "revealCards") {
        const card_hash = await makeSignature(web3, args.hash)
        console.log(card_hash, args.hash)
        return contract.methods[method](args.game_id, card_hash, args.hash)
    }
    assert(false);
}